// Only the three persistence methods are imported from production source.
// No UIKit, vendor static library, app delegate, or network code is linked.
#import <Foundation/Foundation.h>

typedef NSSize CGSize;
#define CGSizeMake NSMakeSize
#define NSStringFromCGSize NSStringFromSize
#define CGSizeFromString NSSizeFromString
#define FG_SAFE_SETTER(variable, value) variable = (value)

typedef NS_ENUM(NSInteger, ContentPreferenceType) {
    ContentPreferenceTypeSurvey, ContentPreferenceTypeShop,
    ContentPreferenceTypeAdvertising, ContentPreferenceTypeChicagoBulls1,
    ContentPreferenceTypeChicagoBulls2
};

@interface UIImage : NSObject
@property(nonatomic, strong) NSData *bytes;
+ (instancetype)imageWithData:(NSData *)data scale:(double)scale;
@end
@implementation UIImage
+ (instancetype)imageWithData:(NSData *)data scale:(double)scale {
    (void)scale;
    UIImage *image = [UIImage new]; image.bytes = data; return image;
}
@end
static NSData *UIImagePNGRepresentation(UIImage *image) { return image.bytes; }

static NSUserDefaults *isolatedDefaults;
@interface TestUserDefaults : NSObject
+ (instancetype)standardUserDefaults;
- (id)objectForKey:(NSString *)key;
- (void)setObject:(id)value forKey:(NSString *)key;
- (BOOL)synchronize;
@end
@implementation TestUserDefaults
+ (instancetype)standardUserDefaults {
    static TestUserDefaults *proxy;
    if (proxy == nil) proxy = [TestUserDefaults new];
    return proxy;
}
- (id)objectForKey:(NSString *)key { return [isolatedDefaults objectForKey:key]; }
- (void)setObject:(id)value forKey:(NSString *)key {
    // Modern Foundation may abort rather than throw for unsupported values.
    // Its actual property-list validator makes the invalid baseline safely
    // observable before forwarding valid data to the real isolated defaults.
    if (![NSPropertyListSerialization propertyList:value isValidForFormat:NSPropertyListBinaryFormat_v1_0]) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Not a property list" userInfo:nil];
    }
    [isolatedDefaults setObject:value forKey:key];
}
- (BOOL)synchronize { return [isolatedDefaults synchronize]; }
@end

@interface ContentPreference : NSObject {
@public
    ContentPreferenceType mType;
    NSString *mBackgroundUrl;
    UIImage *mDefaultButtonImage, *mButtonImage, *mButtonOpenImage;
    NSString *mButtonImageUrl, *mButtonOpenImageUrl, *mContentUrl, *mHintText;
    CGSize mButtonSize, mContentSize;
}
- (NSString *)stringFromType:(ContentPreferenceType)type;
- (void)loadFromSetting;
- (void)saveToSetting;
@end
@implementation ContentPreference
// Route only standardUserDefaults to a fresh synthetic suite, leaving the
// actual Foundation dictionary/property-list validation and storage intact.
#define NSUserDefaults TestUserDefaults
#include "ProductionPersistence.inc"
#undef NSUserDefaults
@end

static void require(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message.UTF8String);
        @throw [NSException exceptionWithName:@"TestFailure" reason:message userInfo:nil];
    }
}
static UIImage *image(NSString *text) {
    return [UIImage imageWithData:[text dataUsingEncoding:NSUTF8StringEncoding] scale:2.0];
}
static ContentPreference *sample(void) {
    ContentPreference *prefs = [ContentPreference new];
    prefs->mType = ContentPreferenceTypeSurvey;
    prefs->mBackgroundUrl = @"https://example.invalid/background";
    prefs->mDefaultButtonImage = image(@"default");
    prefs->mButtonImage = image(@"custom button PNG stand-in");
    prefs->mButtonOpenImage = image(@"custom open PNG stand-in");
    prefs->mButtonImageUrl = @"https://example.invalid/button";
    prefs->mButtonOpenImageUrl = @"https://example.invalid/open";
    prefs->mContentUrl = @"https://example.invalid/content";
    prefs->mHintText = @"synthetic hint";
    prefs->mButtonSize = CGSizeMake(72, 64); prefs->mContentSize = CGSizeMake(320, 400);
    return prefs;
}
static NSDictionary *saved(ContentPreference *prefs) {
    return [isolatedDefaults objectForKey:[prefs stringFromType:prefs->mType]];
}
static void testPersistence(void) {
    ContentPreference *prefs = sample();
    [prefs saveToSetting];
    NSDictionary *params = saved(prefs);
    require([[params objectForKey:@"ButtonImage"] isKindOfClass:[NSData class]], @"saved custom image must be NSData");
    require([[params objectForKey:@"ButtonOpenImage"] isKindOfClass:[NSData class]], @"saved open image must be NSData");
    require([NSPropertyListSerialization propertyList:params isValidForFormat:NSPropertyListBinaryFormat_v1_0], @"saved values are a valid property list");
    ContentPreference *loaded = [ContentPreference new]; loaded->mType = prefs->mType;
    [loaded loadFromSetting];
    require([loaded->mButtonImage.bytes isEqual:prefs->mButtonImage.bytes], @"button image round trip");
    require([loaded->mButtonOpenImage.bytes isEqual:prefs->mButtonOpenImage.bytes], @"open image round trip");
    require([loaded->mButtonImageUrl isEqual:prefs->mButtonImageUrl] && [loaded->mButtonOpenImageUrl isEqual:prefs->mButtonOpenImageUrl], @"image URL round trip");
    require([loaded->mHintText isEqual:prefs->mHintText] && [loaded->mBackgroundUrl isEqual:prefs->mBackgroundUrl] && [loaded->mContentUrl isEqual:prefs->mContentUrl], @"other preferences survive custom image save");
    require(NSEqualSizes(loaded->mButtonSize,prefs->mButtonSize) && NSEqualSizes(loaded->mContentSize,prefs->mContentSize), @"size round trip");

    prefs->mButtonImage = prefs->mDefaultButtonImage; prefs->mButtonOpenImage = prefs->mDefaultButtonImage;
    [prefs saveToSetting]; params = saved(prefs);
    require(params[@"ButtonImage"] == nil && params[@"ButtonOpenImage"] == nil, @"default images are not persisted");
    prefs->mButtonImage = nil; prefs->mButtonOpenImage = nil;
    [prefs saveToSetting]; params = saved(prefs);
    require(params[@"ButtonImage"] == nil && params[@"ButtonOpenImage"] == nil, @"nil images omitted");
    prefs->mButtonImage = [UIImage new]; prefs->mButtonOpenImage = [UIImage new];
    [prefs saveToSetting]; params = saved(prefs);
    require(params[@"ButtonImage"] == nil && params[@"ButtonOpenImage"] == nil && params[@"HintText"] != nil, @"failed encodings do not corrupt other preferences");
    prefs->mButtonImage = image(@"replacement"); prefs->mButtonOpenImage = image(@"open replacement");
    [prefs saveToSetting]; [loaded loadFromSetting];
    require([loaded->mButtonImage.bytes isEqual:prefs->mButtonImage.bytes] && [loaded->mButtonOpenImage.bytes isEqual:prefs->mButtonOpenImage.bytes], @"repeated edits persist latest image bytes");
    puts("PASS: production preference save/load, property-list validation, image round trips, defaults, nil/failed encoding, repeated edits");
}
int main(void) {
    @autoreleasepool {
        NSString *suite = [@"ProBtnOfflineRegression." stringByAppendingString:[NSUUID UUID].UUIDString];
        isolatedDefaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        int result = 0;
        @try { testPersistence(); }
        @catch (NSException *exception) { fprintf(stderr, "%s\n", exception.reason.UTF8String); result = 1; }
        @finally { [isolatedDefaults removePersistentDomainForName:suite]; }
        return result;
    }
}
