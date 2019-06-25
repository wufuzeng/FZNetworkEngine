//
//  FZNetworkResponseFilter.h
//  FZOCProject
//
//  Created by 吴福增 on 2019/3/29.
//  Copyright © 2019 wufuzeng. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FZNetworkResponseFilter : NSObject

/**
 成功过滤器
 
 @param resposeObj 成功的数据
 @param result 返回block
 */
+(void)handleSuccessWithUrl:(NSString*)url
                     params:(NSDictionary*)params
                headerField:(NSDictionary*)headerField
                 resposeObj:(id  _Nullable)resposeObj
                     result:(void (^)(id _Nullable responseDict,NSError * _Nullable error))result;

/**
 失败过滤器
 
 @param error 失败类
 @param result 返回block
 */
+(void)handleErrorWithUrl:(NSString*)url
                   params:(NSDictionary*)params
              headerField:(NSDictionary*)headerField
               resposeObj:(id  _Nullable)resposeObj
                    error:(NSError *)error
                   result:(void (^)(id _Nullable responseDict,NSError * _Nullable error))result;

@end

NS_ASSUME_NONNULL_END
