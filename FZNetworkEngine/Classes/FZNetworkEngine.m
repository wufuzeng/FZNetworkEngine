
//
//  FZNetworkEngine.m
//  美丽吧
//
//  Created by 吴福增 on 2018/10/18.
//  Copyright © 2018 wufuzeng. All rights reserved.
//

#import "FZNetworkEngine.h"
#import "FZNetworkResponseFilter.h"
#import "AFNetworkActivityIndicatorManager.h"

NSString * const POST_METHOD = @"POST";
NSString * const GET_METHOD  = @"GET";

#import <objc/runtime.h>

/**
 *  SSL 证书名称，仅支持cer格式。“app.bishe.com.cer”,则填“app.bishe.com”
 */
#define certRoot @"rootCer.cer"


static NSString * const SSLCerName  = @"SSLCerName";

@interface FZNetworkEngine ()
/** 是否开启监听 */
@property (nonatomic,assign) BOOL isMonitorNet;
/** 网络状态 */
@property (nonatomic,assign) AFNetworkReachabilityStatus netStatus;
/** 任务 */
@property (nonatomic, strong) NSMutableDictionary *tasks;
/** HTTPS证书认证 */
@property (nonatomic,strong) AFSecurityPolicy *securityPolicy;

@end

@implementation FZNetworkEngine

const char *kUPLOADMANAGERS;

+ (NSMutableArray <AFHTTPSessionManager *>*)getUploadManagers {
    return objc_getAssociatedObject(self, &kUPLOADMANAGERS);
}

+ (void)setUploadManagers:(AFHTTPSessionManager *)manager {
    if (!manager) {
        return;
    }
    NSMutableArray *arrM = [self getUploadManagers];
    if (!arrM) {
        arrM = [NSMutableArray array];
    }
    [arrM addObject:manager];
    objc_setAssociatedObject(self, &kUPLOADMANAGERS, arrM, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)cancelAllUploadTask {
    NSMutableArray *arrM = [self getUploadManagers];
    for (AFHTTPSessionManager *manager in arrM) {
        [manager.operationQueue cancelAllOperations];
    }
}


+ (instancetype)shareNetwork {
    static FZNetworkEngine *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        [instance monitorNetWorkSyle];
    });
    return instance;
}

/**
 网络请求
 @param method      "GET","POST"
 @param url         url
 @param params      参数
 @param isKeepFirst   保留首次请求
 @param libraryType        库类型
 @param headerfield 头部
 @param progress code
 @param callBack code
 */
- (NSURLSessionTask * _Nullable)method:(NSString *_Nullable)method
           url:(NSString *_Nullable)url
        params:(NSDictionary *_Nullable)params
     keepFirst:(BOOL)isKeepFirst 
   libraryType:(LibraryType)libraryType
   headerfield:(RequestHeaderBlock _Nullable )headerfield
      progress:(ProgressBlock _Nullable)progress
        finish:(void(^_Nullable)(NSDictionary *_Nullable responseDict, NSError *_Nullable error))callBack {
    
    NSURLSessionDataTask *originalTask = [self.tasks objectForKey:url];
    
    if (isKeepFirst && originalTask) {
        return originalTask;
    }else{
        [originalTask cancel];
    }
    NSURLSessionTask *task = nil;
    
    if (self.isMonitorNet && self.netStatus == AFNetworkReachabilityStatusNotReachable) {
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
    }else{
        if (libraryType == LibraryTypeSys) {
            task = [FZNetworkEngine netWorkWithURL:url urlMethod:method params:params synchronization:NO setHeaderfield:headerfield result:^(NSDictionary * _Nullable responseDict, NSError * _Nullable error) {
                [self.tasks removeObjectForKey:url];
                callBack(responseDict,error);
            }];
            
        } else if (libraryType == LibraryTypeAFN){
            if ([method isEqualToString:@"GET"]) {
                task = [FZNetworkEngine getRequestWithURL:url params:params headerfield:headerfield progress:progress result:^(NSDictionary * _Nullable responseDict, NSError * _Nullable error) {
                    [self.tasks removeObjectForKey:url];
                    callBack(responseDict,error);
                }];
            } else if ([method isEqualToString:@"POST"]) {
                task = [FZNetworkEngine postRequestWithURL:url params:params headerfield:headerfield progress:progress result:^(NSDictionary * _Nullable responseDict, NSError * _Nullable error) {
                    [self.tasks removeObjectForKey:url];
                    callBack(responseDict,error);
                }];
            }else{
                //return;
            }
        }
    }
    if (task) {
        [self.tasks setValue:task forKey:url];
    }
    return task;
}



#pragma mark -- 苹果源生方法，NSMutitablehttpRequest --------------

/**
 利用NSMutableURLRequest 实现的http请求
 
 @param url        请求的url或者action
 @param params          post数据
 @param setHeaderfield  设置请求头
 @param synchronization 是否同步执行
 @param result          返回的bolck
 @return task
 */
+(NSURLSessionTask *)netWorkWithURL:(NSString *_Nullable)url
                          urlMethod:(NSString *_Nullable)method
                             params:(id _Nullable)params
                    synchronization:(BOOL)synchronization
                     setHeaderfield:(RequestHeaderBlock _Nullable )setHeaderfield
                             result:(FinishBlock _Nullable )result{
    url = [url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"`#%^{}\"[]|\\<> "].invertedSet];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod = method;
    if ([params isKindOfClass:[NSString class]]){
        request.HTTPBody = [params dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([params isKindOfClass:[NSDictionary class]]){
        NSDictionary *postDic = params;
        if (postDic){
            NSString *string = @"";
            for (NSString *key in postDic) {
                string = [string stringByAppendingString:[NSString stringWithFormat:@"%@=%@&",key,postDic[key]]];
            }
            string = [string substringToIndex:string.length-1];
            string = [string stringByAppendingString:@"&type=JSON"];
            request.HTTPBody = [string dataUsingEncoding:NSUTF8StringEncoding];
        }
    }
    
    if (setHeaderfield) {
        setHeaderfield(request);
    }
    [request setValue:@"application/json;text/html;" forHTTPHeaderField:@"Content-Type"];
   
    dispatch_semaphore_t disp = NULL;
    if(synchronization){
        disp = dispatch_semaphore_create(0);
    }
    
    NSURLSessionTask *task = [session dataTaskWithRequest:request
                                        completionHandler:^(NSData *data,
                                                            NSURLResponse *response,
                                                            NSError *error) {
        NSHTTPURLResponse *subResponse = (NSHTTPURLResponse *)response;
        NSDictionary *allHeaders = subResponse.allHeaderFields;
        if (error) {
            [FZNetworkResponseFilter handleErrorWithUrl:url params:params headerField:allHeaders resposeObj:nil error:error result:result];
        }else{
            if (data) {
                NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
                dispatch_async(dispatch_get_main_queue(), ^(){
                    [FZNetworkResponseFilter handleSuccessWithUrl:url params:params headerField:allHeaders resposeObj:dic result:result];
                });
            }else{
                NSError *error = [NSError errorWithDomain:@"返回的数据为空！！！" code:0 userInfo:nil];
                [FZNetworkResponseFilter handleErrorWithUrl:url params:params headerField:allHeaders resposeObj:nil error:error result:result];
            } 
        }
                                            
        if (synchronization) {
            dispatch_semaphore_signal(disp);
        }
    }];
    [task resume];
    if (synchronization) {
        dispatch_semaphore_wait(disp, DISPATCH_TIME_FOREVER);
    }
    return task;
}


+(void)getTaskWithURL:(NSString *_Nullable)urlString
               params:(id _Nullable)params
       setHeaderfield:(RequestHeaderBlock _Nullable )setHeaderfield
               result:(FinishBlock _Nullable )result{
    [FZNetworkEngine netWorkWithURL:urlString urlMethod:GET_METHOD params:params synchronization:NO setHeaderfield:setHeaderfield result:result];
}

+(void)postTaskWithURL:(NSString *_Nullable)urlString
                params:(id _Nullable)params
         enableLoading:(BOOL)enableLoading
        setHeaderfield:(RequestHeaderBlock _Nullable )setHeaderfield
                result:(FinishBlock _Nullable )result{
    [FZNetworkEngine netWorkWithURL:urlString urlMethod:POST_METHOD params:params synchronization:NO setHeaderfield:setHeaderfield result:result];
}



#pragma mark - AFNetWorking  ------------

/**
 afn封装的post方法
 
 @param url 请求地址
 @param params 发送的数据
 @param headerfield 设置请求头
 @param progress 下载进度
 @param result 返回操作
 */
+(NSURLSessionDataTask *)postRequestWithURL:(NSString *_Nullable)url
                                     params:(NSDictionary *_Nullable)params
                                headerfield:(RequestHeaderBlock _Nullable )headerfield
                                   progress:(ProgressBlock _Nullable)progress
                                     result:(FinishBlock _Nullable)result{
    
    if (headerfield) {
        headerfield([FZNetworkEngine shareNetwork].manager.requestSerializer);
    }
    NSURLSessionDataTask *task = [[FZNetworkEngine shareNetwork].manager POST:url parameters:params progress:^(NSProgress * _Nonnull downloadProgress) {
        if (progress) {
            progress(downloadProgress);
        }
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSError *error = nil;
        if (responseObject) {
            [FZNetworkResponseFilter handleSuccessWithUrl:url params:params headerField:[FZNetworkEngine shareNetwork].manager.requestSerializer.HTTPRequestHeaders resposeObj:responseObject result:result];
        } else {
            error = [NSError errorWithDomain:@"返回的数据为空！！！" code:0 userInfo:nil];
            [FZNetworkResponseFilter handleErrorWithUrl:url params:params headerField:[FZNetworkEngine shareNetwork].manager.requestSerializer.HTTPRequestHeaders resposeObj:responseObject error:error result:result];
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [FZNetworkResponseFilter handleErrorWithUrl:url params:params headerField:[FZNetworkEngine shareNetwork].manager.requestSerializer.HTTPRequestHeaders resposeObj:nil error:error result:result];
    }];
    
    return task;
}
/**
 afn封装的get方法
 
 @param url 请求地址
 @param params 发送的数据
 @param headerfield 设置请求头
 @param progress 下载进度
 @param result 返回操作
 */
+(NSURLSessionDataTask *)getRequestWithURL:(NSString *_Nullable)url
                                     params:(NSDictionary *_Nullable)params
                                headerfield:(RequestHeaderBlock _Nullable )headerfield
                                   progress:(ProgressBlock _Nullable)progress
                                     result:(FinishBlock _Nullable)result{
    
    if (headerfield) {
        headerfield([FZNetworkEngine shareNetwork].manager.requestSerializer);
    }
    
    NSURLSessionDataTask *task = [[FZNetworkEngine shareNetwork].manager GET:url parameters:params progress:^(NSProgress * _Nonnull downloadProgress) {
        if (progress) {
            progress(downloadProgress);
        }
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSError *error = nil;
        if (responseObject) {
            [FZNetworkResponseFilter handleSuccessWithUrl:url params:params headerField:[FZNetworkEngine shareNetwork].manager.requestSerializer.HTTPRequestHeaders resposeObj:responseObject result:result];
        } else {
            //error = [NSError errorWithDomain:@"返回的数据为空！！！" code:0 userInfo:nil];
            error = [[NSError alloc] initWithDomain:url code:-1990 userInfo:@{@"error" : @"请求成功，但数据为空"}];
            [FZNetworkResponseFilter handleErrorWithUrl:url params:params headerField:[FZNetworkEngine shareNetwork].manager.requestSerializer.HTTPRequestHeaders resposeObj:nil error:error result:result];
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [FZNetworkResponseFilter handleErrorWithUrl:url params:params headerField:[FZNetworkEngine shareNetwork].manager.requestSerializer.HTTPRequestHeaders resposeObj:nil error:error result:result];
    }];
    
    return task;
}

/**
  上传图图片文件
 
    NSUInteger i = 0 ;
    //出于性能考虑,将上传图片进行压缩
    for (UIImage * image in images){
        NSData * fileData = UIImageJPEGRepresentation(image, 1);;
        CGFloat scale     = 1;
        // 大于2m压缩
        if ([fileData lengthWithUnit:WFZDataSizeUnitM] > 2){
            fileData = [image compressByQualitytoMaxDataSizeKBytes:1000*2];
        }
        //拼接data
        [formData appendPartWithFileData:fileData
                                    name:images.count>1?[NSString stringWithFormat:@"flie%ld",(long)i]:@"file"
                                fileName:[NSString stringWithFormat:@"%@.png",[NetWorkManager randomString]]
                                mimeType:@"image/jpeg"];
        i++;
    }
 */

-(NSURLSessionDataTask *_Nullable)uploadRequestWithURL:(NSString *_Nullable)url
                                                params:(id _Nonnull )params
                                                  body:(void (^_Nullable)(id <AFMultipartFormData> _Nullable formData))body
                                              progress:(ProgressBlock _Nullable)progress
                                                result:(FinishBlock _Nullable)result{
    
    
    NSURLSessionDataTask * task = [[FZNetworkEngine shareNetwork].manager POST:url parameters:params constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        if (body) {
            body(formData);
        }
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        if (progress){
            progress(uploadProgress);
        }
    } success:^(NSURLSessionDataTask * _Nonnull task, NSDictionary *  _Nullable responseObject) {
        NSError *error = nil;
        if (responseObject) {
            [FZNetworkResponseFilter handleSuccessWithUrl:url params:params headerField:[FZNetworkEngine shareNetwork].manager.requestSerializer.HTTPRequestHeaders resposeObj:responseObject result:result];
        } else {
            error = [[NSError alloc] initWithDomain:url code:-1990 userInfo:@{@"error" : @"请求成功，但数据为空"}];
            [FZNetworkResponseFilter handleErrorWithUrl:url params:params headerField:[FZNetworkEngine shareNetwork].manager.requestSerializer.HTTPRequestHeaders resposeObj:nil error:error result:result];
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
       
        [FZNetworkResponseFilter handleErrorWithUrl:url params:params headerField:[FZNetworkEngine shareNetwork].manager.requestSerializer.HTTPRequestHeaders resposeObj:nil error:error result:result];
    }];
    return task;
}


/**
 *  文件下载
 *
 *  @param url          请求的url
 *  @param params       文件下载预留参数
 *  @param savePath     下载文件保存路径
 *  @param progress     下载文件的进度显示
 *  @param result       下载文件的回调
 */
-(NSURLSessionTask *_Nullable)downLoadRequestWithURL:(NSString *_Nullable)url
                                              params:(NSDictionary *_Nullable)params
                                            savaPath:(NSString *_Nullable)savePath
                                            progress:(ProgressBlock _Nullable)progress
                                              result:(FinishBlock _Nullable)result{
    
    NSURLSessionDownloadTask *task = [[FZNetworkEngine shareNetwork].manager downloadTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]] progress:^(NSProgress * _Nonnull downloadProgress) {
        if (progress){
            progress(downloadProgress);
        }
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        NSString *path = [savePath stringByAppendingPathComponent:response.suggestedFilename];
        return [NSURL fileURLWithPath:path];
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        if (error){
            [FZNetworkResponseFilter handleErrorWithUrl:url params:params headerField:@{} resposeObj:nil error:error result:result];
        } else {
            NSError *error = nil;
            if (filePath) {
                [FZNetworkResponseFilter handleSuccessWithUrl:url params:params headerField:@{} resposeObj:@{@"path":filePath} result:result];
            } else {
                error = [[NSError alloc] initWithDomain:url code:-1990 userInfo:@{@"error" : @"请求成功，但数据为空"}];
                [FZNetworkResponseFilter handleErrorWithUrl:url params:params headerField:@{} resposeObj:nil error:error result:result];
            }
        }
    }];
    [task resume];
    return task;
}


/**
 *  取消所有的网络请求
 */
-(void)cancelAllRequest{
    [self.manager.operationQueue cancelAllOperations];
}
/**
 *  取消指定的url请求
 *
 *  @param method 该请求的请求类型
 *  @param url      该请求的url
 */
-(void)cancelRequestWithMethod:(NSString *_Nullable)method
                           url:(NSString *_Nullable)url{
    NSError * error;
    
    /**
     *  根据请求的类型 以及 请求的url创建一个NSMutableURLRequest
     *  通过该url去匹配请求队列中是否有该url,如果有的话 那么就取消该请求
     */
    
    NSString * urlToPeCanced = [[[self.manager.requestSerializer requestWithMethod:method URLString:url parameters:nil error:&error] URL] path];
    for (NSOperation * operation in self.manager.operationQueue.operations){
        //如果是请求队列
        if ([operation isKindOfClass:[NSURLSessionTask class]]){
            //请求的类型匹配
            BOOL hasMatchRequestType = [method isEqualToString:[[(NSURLSessionTask *)operation currentRequest] HTTPMethod]];
            //请求的url匹配
            BOOL hasMatchRequestUrlString = [urlToPeCanced isEqualToString:[[[(NSURLSessionTask *)operation currentRequest] URL] path]];
            //两项都匹配的话  取消该请求
            if (hasMatchRequestType && hasMatchRequestUrlString){
                [operation cancel];
            }
        }
    }
}



/**
 *  监控网络类型
 *  wifi,蜂窝网络,没有网
 */
-(void)monitorNetWorkSyle{
    [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status){
        /** 已开启监听 */
        self.isMonitorNet = YES;
        self.netStatus = status;
         switch (status){
             case AFNetworkReachabilityStatusUnknown:{
                 NSLog(@"当前网络未知");
                 break;}
             case AFNetworkReachabilityStatusNotReachable:{
                 NSLog(@"当前无网络");
                 break;}
             case AFNetworkReachabilityStatusReachableViaWWAN:{
                 NSLog(@"当前是蜂窝网络");
                 break;}
             case AFNetworkReachabilityStatusReachableViaWiFi:{
                 NSLog(@"当前是wifi环境");
                 break;}
             default:
                 break;
         }
         NSLog(@"Reachability: %@", AFStringFromNetworkReachabilityStatus(status));
     }];
    
    //开启网络检测
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    
    /**
     *  网络活动发生变化时,会发送下方key 的通知,可以在通知中心中添加检测
     *
     *  [[NSNotificationCenter defaultCenter] addObserver:nil selector:nil name:AFNetworkingReachabilityDidChangeNotification object:nil];
     */
    
}

#pragma mark -- 设置证书 ---

/**
 * 配置自签名证书
 * 证书配置【这里支持多证书, 添加到pathCers中即可】
 * 采用多证书验证的方式 的使用场景是这样的：比如当我们访问了多个不同的服务器 而这些服务器又分别用了不同的安全证书，所以需要以此对证书进行验证
 */
+ (void)setCertificateForCustomSecurityPolicyWithCerPaths:(NSArray<NSString *> * _Nullable)cerPaths
                                               andManager:(AFHTTPSessionManager * _Nullable)manager{
    
    AFHTTPSessionManager *weakManager = manager;//防止循环引用
    /**
     * 先导入证书
     * 证书由服务端生成，具体由服务端人员操作
     */
    NSString *cerPath = [[NSBundle mainBundle] pathForResource:SSLCerName ofType:@"cer"];//证书的路径
    NSData *certData = [NSData dataWithContentsOfFile:cerPath];
    /**
     * 添加证书
     * 注意只有自签名证书或者免费证书才需要设置【如果是付费证书可以不用做任何设置】
     */
    // AFSSLPinningModeCertificate 使用证书验证模式
    AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate];
    /**
     * allowInvalidCertificates
     * 验证自建证书(无效证书)设置为YES
     * 是否允许无效证书（也就是自建的证书），默认为NO
     * 如果是需要验证自建证书，需要设置为YES
     */
    securityPolicy.allowInvalidCertificates = YES;
    /**
     validatesDomainName 验证域名，默认为YES；
     如证书的域名与你请求的域名不一致，需把该项设置为NO；
     如设成NO的话，即服务器使用其他可信任机构颁发的证书，也可以建立连接，这个非常危险，建议打开。
     置为NO，主要用于这种情况：
     客户端请求的是子域名，而证书上的是另外一个域名。
     因为SSL证书上的域名是独立的，假如证书上注册的域名是www.google.com，那么mail.google.com是无法验证通过的；
     当然，有钱可以注册通配符的域名*.google.com，但这个还是比较贵的。
     如置为NO，建议自己添加对应域名的校验逻辑。
     */
    securityPolicy.validatesDomainName = NO;
    NSMutableSet *mSet = [NSMutableSet setWithObject:certData];
    securityPolicy.pinnedCertificates = mSet;
    
    //设置自签名证书
    weakManager.securityPolicy = securityPolicy;
    
}

/**
 * 配置服务器证书或根证书
 * 证书配置【这里支持多证书, 添加到pathCers中即可】
 * 采用多证书验证的方式 的使用场景是这样的：比如当我们访问了多个不同的服务器 而这些服务器又分别用了不同的安全证书，所以需要以此对证书进行验证
 */
+ (void)setCertificateForHTTPSWithCerPaths:(NSArray<NSString *> * _Nullable)cerPaths
                                andManager:(AFHTTPSessionManager * _Nullable)manager {
    
    AFHTTPSessionManager *weakManager = manager;//防止循环引用
    
    AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate];
    securityPolicy.allowInvalidCertificates = YES;      //是否允许使用自签名证书
    securityPolicy.validatesDomainName = NO;           //是否需要验证域名
    
    /*
     * 服务端在接收到客户端请求时会有的情况需要验证客户端证书，要求客户端提供合适的证书，再决定是否返回数据。
     * 这种情况即为质询(challenge)认证,双方进行公钥和私钥的验证。
     * 为实现客户端验证，manager须设置需要身份验证回调的方法
     */
    //质询
    [manager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession *session, NSURLAuthenticationChallenge *challenge, NSURLCredential *__autoreleasing *_credential) {
        
        /// 获取服务器的trust object
        SecTrustRef serverTrust = [[challenge protectionSpace] serverTrust];
        
        NSData *caCert = nil;
        
        //NSMutableArray *dataMCer = [NSMutableArray array];
        for (NSString *Path in cerPaths){
            caCert = [NSData dataWithContentsOfFile:Path];
            //[dataMCer addObject:caCert];
        }
        //设置自签名证书
        //weakManager.securityPolicy.pinnedCertificates = dataMCer;
        
        SecCertificateRef caRef = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)caCert);
        NSCAssert(caRef != nil, @"caRef is nil");
        NSArray *caArray = @[(__bridge id)(caRef)];
        NSCAssert(caArray != nil, @"caArray is nil");
        
        // 将读取到的证书设置为serverTrust的根证书
        OSStatus status = SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)caArray);
        SecTrustSetAnchorCertificatesOnly(serverTrust,NO);
        NSCAssert(errSecSuccess == status, @"SecTrustSetAnchorCertificates failed");
        
        //选择质询认证的处理方式
        NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        __autoreleasing NSURLCredential *credential = nil;
        
        //NSURLAuthenticationMethodServerTrust质询认证方式
        if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
            //基于客户端的安全策略来决定是否信任该服务器，不信任则不响应质询。
            if ([weakManager.securityPolicy evaluateServerTrust:challenge.protectionSpace.serverTrust forDomain:challenge.protectionSpace.host]) {
                //创建质询证书
                credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
                //确认质询方式
                if (credential) {
                    disposition = NSURLSessionAuthChallengeUseCredential;
                } else {
                    disposition = NSURLSessionAuthChallengePerformDefaultHandling;
                }
            } else {
                //取消挑战
                disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }
        }else{
            disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        }
        
        return disposition;
    }];
}


#pragma mark -- 工具方法 ---------

/**
 字典转json
 
 @param dic 要转换的字典
 @return 转换成json的字符串
 */
+(NSString * _Nullable)dicToJsonString:(NSDictionary * _Nullable)dic;{
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&parseError];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}


/**
 json字符串转字典
 
 @param string json字符串
 @return 转换成模型
 */
+(NSDictionary * _Nullable)jsonStringToDic:(NSString * _Nullable)string;{
    if (string == nil || ![string isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSData *jsonData = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&error];
    if(error){
        NSLog(@"json解析失败：%@",error);
        return nil;
    }
    return dic;
}


/**
 获取时间
 
 @return 181106123026 (2018-11-06 12:30:26)
 */
+ (NSString * _Nullable)getTimeStamp;{
    //获取系统的时间日期
    NSDate *  senddate = [NSDate date];
    NSDateFormatter  *dateformatter = [[NSDateFormatter alloc] init];
    [dateformatter setDateFormat:@"yyyyMMddHHmmss"];
    NSString *  dateString = [dateformatter stringFromDate:senddate];
    dateString = [dateString substringFromIndex:2];
    return dateString;
}


/**
 *   解析Cookie获取kTokenID
 */
-(NSString *)getUserTokenIdInCookie:(NSString *)cookie{
    //例如 ：JSESSIONID=25F6DBC6AB286542F37D58B8EDBB84BD; Path=/pad, cookie_user=fsdf#~#sdfs.com; Expires=Tue, 26-Nov-2013 06:31:33 GMT, cookie_pwd=123465; Expires=Tue, 26-Nov-2013 06:31:33 GMT
    NSString *basic_str = @"";
    NSArray *theArray = [cookie componentsSeparatedByString:@"; "];
    for (int i =0 ; i<[theArray count]; i++){
        NSString *val=theArray[i];
        if ([val rangeOfString:@"JSESSIONID="].length>0){
            basic_str = val;
        }
    }
    return basic_str;
}



#pragma mark -- Lazy Func -------------------------------


- (NSMutableDictionary *)tasks {
    if (_tasks == nil) {
        _tasks = [NSMutableDictionary dictionary];
    }
    return _tasks;
}


/** AFNetWorking */
- (AFHTTPSessionManager *)manager{
    if (_manager == nil) {
        _manager = [AFHTTPSessionManager manager];
        
        //1.设置请求类型
        _manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects: @"application/json",
                                                                                    @"text/json",
                                                                                    @"text/javascript",
                                                                                    @"text/html",
                                                                                    @"text/xml",
                                                                                    @"text/plain",
                                                                                    nil];
        
        //默认 NSUTF8StringEncoding
        _manager.responseSerializer.stringEncoding =  NSUTF8StringEncoding;
        
        //2.最大请求并发任务数
        _manager.operationQueue.maxConcurrentOperationCount = 10;
        
        // 请求格式
        // AFHTTPRequestSerializer            二进制格式
        // AFJSONRequestSerializer            JSON
        // AFPropertyListRequestSerializer    PList(是一种特殊的XML,解析起来相对容易)
        _manager.requestSerializer = [AFHTTPRequestSerializer serializer]; // 上传普通格式
        
        //3.超时时间
        _manager.requestSerializer.timeoutInterval = 30.0f;
        
        
        /**
         *  4.设置接收的Content-Type
         *  @[@"application/json",@"text/xml",@"text/plain", @"text/html",@"application/xml"]
         */
        _manager.responseSerializer.acceptableContentTypes = [NSSet setWithArray:@[@"text/html",
                                                                                   @"text/plain",
                                                                                   @"text/xml",
                                                                                   @"text/html",
                                                                                   @"text/json",
                                                                                   @"text/javascript",
                                                                                   @"application/json",
                                                                                   @"application/atom+xml",
                                                                                   @"application/xml",
                                                                                   @"application/x-plist",
                                                                                   @"image/*",
                                                                                   @"*/*",]];

        /**
             返回格式
             AFHTTPResponseSerializer           二进制格式
             AFJSONResponseSerializer           JSON
             AFXMLParserResponseSerializer      XML,只能返回XMLParser,还需要自己通过代理方法解析
             AFXMLDocumentResponseSerializer (Mac OS X)
             AFPropertyListResponseSerializer   PList
             AFImageResponseSerializer          Image
             AFCompoundResponseSerializer       组合
             5.设置返回Content-type 返回格式 JSON
         */
        _manager.responseSerializer = [AFJSONResponseSerializer serializer];
        
        //6.设置请求头
        [_manager.requestSerializer setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
        
        /**
         NSArray *temp_array = [NAMEANDPWFORBASIC componentsSeparatedByString:@"#"];
         [_manager.requestSerializer setAuthorizationHeaderFieldWithUsername:temp_array[0] password:temp_array[1]];
         */
        //默认证书
        AFSecurityPolicy *securityPolicy = [AFSecurityPolicy defaultPolicy];
        securityPolicy.allowInvalidCertificates = YES;
        //_manager.securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
        _manager.securityPolicy = securityPolicy;
        //配置证书
        //_manager.securityPolicy = self.securityPolicy;
        
        //最大并发数
        _manager.operationQueue.maxConcurrentOperationCount = 2;
    }
    return _manager;
}





 


@end
