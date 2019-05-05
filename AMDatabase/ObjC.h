//
//  ObjC.h
//  AMDatabase
//
//  Created by Ilya Kuznetsov on 5/5/19.
//  Copyright © 2019 Ilya Kuznetsov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ObjC : NSObject

+ (BOOL)catchException:(void(^)(void))tryBlock error:(__autoreleasing NSError **)error;

@end
