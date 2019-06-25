//
//  FZNetworkResponseFilter.m
//  FZOCProject
//
//  Created by 吴福增 on 2019/3/29.
//  Copyright © 2019 wufuzeng. All rights reserved.
//

#import "FZNetworkResponseFilter.h"
#import "FZNetworkEngine.h"

@implementation FZNetworkResponseFilter


#pragma mark -- 过滤器 ------------

/**
 成功过滤器
 
 @param resposeObj 成功的数据
 @param result 返回block
 */
+(void)handleSuccessWithUrl:(NSString*)url
                     params:(NSDictionary*)params
                headerField:(NSDictionary*)headerField
                 resposeObj:(id  _Nullable)resposeObj
                     result:(void (^)(id _Nullable responseDict,NSError * _Nullable error))result {
    
    [FZNetworkResponseFilter workLogWithUrl:url params:params headerField:headerField result:resposeObj error:nil]; 
    if (result) {
        result(resposeObj,nil);
    }
    
}

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
                   result:(void (^)(id _Nullable responseDict,NSError * _Nullable error))result {
    
    [FZNetworkResponseFilter workLogWithUrl:url params:params headerField:headerField result:nil error:error];
    
    if ([error.userInfo[@"NSLocalizedDescription"] isEqualToString:@"cancelled"]) {
        NSLog(@"\n已取消\n");
        return;
    } else if ([error.localizedDescription containsString:@"似乎已断开与互联网的连接"]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"网络不可用" preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction * cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) { }];
        [alert addAction:cancel];
        UIAlertAction * ok = [UIAlertAction actionWithTitle:@"去设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            if ([ [UIApplication sharedApplication] canOpenURL:url]){
                [[UIApplication sharedApplication] openURL:url];
            }
        }];
        [alert addAction:ok];
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        return;
    } else if ([error.localizedDescription containsString:@"请求超时"]){
        NSLog(@"\n请求超时,请检查网络\n");
    } else if (error.code == 100) {
        NSLog(@"服务端希望客户端继续");
    } else if (error.code == 200) {
        NSLog(@"服务端成功接收并处理了客户端的请求 OK (服务器返回全部数据)");
    } else if (error.code == 206) {
        NSLog(@"OK (服务器只返回一部分数据)");
    } else if (error.code == 301) {
        NSLog(@"客户端所请求的URL已经移走,需要客户端重定向到其它的URL");
    } else if (error.code == 304) {
        NSLog(@"客户端所请求的URL未发生变化(客户端需要缓存或配置一数据)");
    } else if (error.code == 400) {
        NSLog(@"客户端请求错误(客户端请求的服务器端无法解析)");
    } else if (error.code == 403) {
        NSLog(@"客户端请求被服务端所禁止");
    } else if (error.code == 404) {
        NSLog(@"客户端所请求的URL在服务端不存在(服务器端没有资源(网页/图片/音频视频))");
    } else if (error.code == 500) {
        NSLog(@"服务端在处理客户端请求时出现异常");
    } else if (error.code == 501) {
        NSLog(@"服务端未实现客户端请求的方法或内容(服务器有问题)");
    } else if (error.code == 502) {
        NSLog(@"此为中间代理返回给客户端的出错信息,表明服务端返回给代理时出错");
    } else if (error.code == 503) {
        NSLog(@"服务端由于负载过高或其它错误而无法正常响应客户端请求");
    } else if (error.code == 504) {
        NSLog(@"此为中间代理返回给客户端的出错信息，表明代理连接服务端出现超时。");
    } else{
        
    }
    
    if (result) {
        result(resposeObj,error);
    }
}

/**
 2018-10-18
 打印网络请求
 @param url    请求链接
 @param params 请求参数
 @param result 返回结果
 */
+(void)workLogWithUrl:(NSString*)url
               params:(NSDictionary*)params
          headerField:(NSDictionary*)headerField
               result:(id  _Nullable)result
                error:(NSError*)error{
    
    if ([FZNetworkEngine shareNetwork].isOpenLog) {
        NSString * links = url;
        for (NSString *key in [params allKeys]){
            links = [NSString stringWithFormat:@"%@%@=%@&",links,key,[params objectForKey:key]];
        }
        links = [NSString stringWithFormat:@"\n---------- 请求地址 -------------：\n\n%@\n\n---------------------\n",links.length>1?[links substringToIndex:links.length-1]:@"拼接失败"]; 
        NSString * header = nil;
        for (NSString *key in headerField.allKeys) {
            header = [NSString stringWithFormat:@"\n---------- 请求头 -------------：\n\n%@\n%@:%@\n\n---------------------\n",header,key,headerField[key]];
        }
        NSString * errorInfo;
        NSString * jsonString;
        if (error) {
            errorInfo = [NSString stringWithFormat:@"\n---------- 发送错误 -------------：\ncode:%ld\nreson:%@\nsuggest:%@\n\n---------------------\n",error.code,error.localizedDescription,error.localizedRecoverySuggestion];
        }else{
            NSError *parseError = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:&parseError];
            NSString *resultString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            if (parseError) {
                jsonString = [NSString stringWithFormat:@"\n---------- 解析失败 -----------：\n\n%@\n\n---------------------\n",result];
            }else{
                jsonString = [NSString stringWithFormat:@"\n---------- 返回JSON -----------：\n\n%@\n\n---------------------\n",resultString];
            }
        }
        NSLog(@"%@%@%@%@",links,header,jsonString,errorInfo);
    }else{
        
    }
    
}


@end
