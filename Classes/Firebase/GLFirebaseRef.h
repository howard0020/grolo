//
//  GLFirebaseRef.h
//  GpsSketchingSample
//
//  Created by sheng on 5/3/14.
//
//

#import <Foundation/Foundation.h>
#import <Firebase/Firebase.h>

@interface GLFirebaseRef : NSObject

+ (Firebase *) userRef;
+ (Firebase *) tripRef;

@end
