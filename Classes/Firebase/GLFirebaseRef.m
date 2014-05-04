//
//  GLFirebaseRef.m
//  GpsSketchingSample
//
//  Created by sheng on 5/3/14.
//
//

#import "GLFirebaseRef.h"

static NSString *FIREBASE_API_KEY = @"";
static NSString *FIREBASE_BASE_URL = @"https://grolo.firebaseio.com";
static NSString *TRIPS_PATH = @"trips";
static NSString *USERS_PATH = @"users";

@implementation GLFirebaseRef

+ (Firebase *) userRef {
    NSString *path = [FIREBASE_BASE_URL stringByAppendingString:USERS_PATH];
    return [[Firebase alloc] initWithUrl: path];
}

+ (Firebase *) tripRef {
    NSString *path = [FIREBASE_BASE_URL stringByAppendingString:TRIPS_PATH];
    return [[Firebase alloc] initWithUrl: path];
}

@end
