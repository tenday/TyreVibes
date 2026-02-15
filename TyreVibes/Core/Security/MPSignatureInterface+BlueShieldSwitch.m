#import <Foundation/Foundation.h>

#if __has_include(<MPSignatureAdapter/MPSignatureAdapter.h>)
#import <MPSignatureAdapter/MPSignatureAdapter.h>

@implementation MPSignatureInterface (BlueShieldSwitch)

+ (MPSecurityComponentType)securityComponentType {
    return MPSecurityComponentTypeBS;
}

@end
#endif
