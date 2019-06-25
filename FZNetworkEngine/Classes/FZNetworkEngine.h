//
//  FZNetworkEngine.h
//  美丽吧
//
//  Created by 吴福增 on 2018/10/18.
//  Copyright © 2018 wufuzeng. All rights reserved.
//

//FZNetworkEngine

#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>

extern NSString * _Nullable const POST_METHOD;
extern NSString * _Nonnull const GET_METHOD;
/**
 * 请求头类型
 * NSMutableURLRequest,  源生
 * AFHTTPRequestSerializer, AFN
 */
typedef void(^RequestHeaderBlock)( id  _Nonnull header);
//进度回调
typedef void(^ProgressBlock)(NSProgress * _Nonnull progress);

//返回字典，错误对象
typedef void (^FinishBlock)(NSDictionary * _Nullable responseDict,NSError * _Nullable error);


typedef NS_ENUM(NSInteger,LibraryType) {
    LibraryTypeSys,//源生
    LibraryTypeAFN,//3rd
};

@interface FZNetworkEngine : NSObject
/** AFNetWorking */
@property (nonatomic,strong) AFHTTPSessionManager * _Nonnull manager;
/** 是否打开日志 */
@property (nonatomic,assign,getter=isOpenLog) BOOL openLog;
/** 单例 */
+ (instancetype _Nonnull)shareNetwork;

/** 网络请求 */
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
- (NSURLSessionTask *_Nullable)method:(NSString *_Nullable)method
                         url:(NSString *_Nullable)url
                      params:(NSDictionary *_Nullable)params 
                   keepFirst:(BOOL)isKeepFirst 
                 libraryType:(LibraryType)libraryType
                 headerfield:(RequestHeaderBlock _Nullable )headerfield
                    progress:(ProgressBlock _Nullable)progress
                      finish:(void(^_Nullable)(NSDictionary *_Nullable responseDict, NSError *_Nullable error))callBack;


/** 上传请求 */
-(NSURLSessionDataTask *_Nullable)uploadRequestWithURL:(NSString *_Nullable)url
                                                params:(id _Nonnull )params
                                                  body:(void (^_Nullable)(id <AFMultipartFormData> _Nullable formData))body
                                              progress:(ProgressBlock _Nullable)progress
                                                result:(FinishBlock _Nullable)result;

/** 下载请求 */
-(NSURLSessionTask *_Nullable)downLoadRequestWithURL:(NSString *_Nullable)url
                                              params:(NSDictionary *_Nullable)params
                                            savaPath:(NSString *_Nullable)savePath
                                   progress:(ProgressBlock _Nullable)progress
                                     result:(FinishBlock _Nullable)result;

/** 取消所有请求 */
-(void)cancelAllRequest;

/** 取消指定请求 */
-(void)cancelRequestWithMethod:(NSString *_Nullable)method
                           url:(NSString *_Nullable)url;

/** 监控网络类型 */
-(void)monitorNetWorkSyle;


#pragma mark -- 设置证书 ---

/**
 * 配置自签名证书
 * 证书配置【这里支持多证书, 添加到pathCers中即可】
 * 采用多证书验证的方式 的使用场景是这样的：比如当我们访问了多个不同的服务器 而这些服务器又分别用了不同的安全证书，所以需要以此对证书进行验证
 */
+ (void)setCertificateForCustomSecurityPolicyWithCerPaths:(NSArray<NSString *> *_Nullable)cerPaths
                                               andManager:(AFHTTPSessionManager *_Nullable)manager;

/**
 * 配置服务器证书或根证书
 * 证书配置【这里支持多证书, 添加到pathCers中即可】
 * 采用多证书验证的方式 的使用场景是这样的：比如当我们访问了多个不同的服务器 而这些服务器又分别用了不同的安全证书，所以需要以此对证书进行验证
 */
+ (void)setCertificateForHTTPSWithCerPaths:(NSArray<NSString *> *_Nullable)cerPaths
                                andManager:(AFHTTPSessionManager *_Nullable)manager;


#pragma mark -- 工具方法 ---------

/**
 字典转json
 
 @param dic 要转换的字典
 @return 转换成json的字符串
 */
+(NSString * _Nullable)dicToJsonString:(NSDictionary * _Nullable)dic;


/**
 json字符串转字典
 
 @param string json字符串
 @return 转换成模型
 */
+(NSDictionary * _Nullable)jsonStringToDic:(NSString * _Nullable)string;


/**
 获取时间
 
 @return 181106123026 (2018-11-06 12:30:26)
 */
+ (NSString * _Nullable)getTimeStamp;


/**
 *   解析Cookie获取kTokenID
 */
-(NSString *_Nullable)getUserTokenIdInCookie:(NSString *_Nullable)cookie;


@end
