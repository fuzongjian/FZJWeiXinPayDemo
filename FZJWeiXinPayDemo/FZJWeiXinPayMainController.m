//
//  FZJWeiXinPayMainController.m
//  FZJWeiXinPayDemo
//
//  Created by fdkj0002 on 16/3/3.
//  Copyright © 2016年 FZJ.com. All rights reserved.
//

#import "FZJWeiXinPayMainController.h"

/**
 *  获取IP相关参数
 */
#import "CommonCrypto/CommonDigest.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>
#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"

#import "ApiXml.h"

#define MCH_ID @"asdfsdhjfasjdfhs"//商户号
#define API_KEY @"asdfhasdjfhalsff"//密钥

#define HTTP @"https://api.mch.weixin.qq.com/pay/unifiedorder"//

@interface FZJWeiXinPayMainController()
@end
@implementation FZJWeiXinPayMainController
-(void)viewDidLoad{
    [super viewDidLoad];
    
    UIButton * testBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    testBtn.frame = CGRectMake(0, 0, 200, 100);
    testBtn.center = self.view.center;
    [testBtn setTitle:@"微信支付测试" forState:UIControlStateNormal];
    testBtn.titleLabel.font = [UIFont systemFontOfSize:20];
    [testBtn addTarget:self action:@selector(testStart) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:testBtn];
    
}
-(void)testStart{
    //    https://pay.weixin.qq.com/wiki/doc/api/app.php?chapter=9_1
    
/**************************************************** 订单信息 *******************************************************************/
    NSString* device = [[UIDevice currentDevice] identifierForVendor].UUIDString;
#warning 调整价格，以分为单位
    NSString * price = @"3";//价格以分为单位
    
    //订单标题，展示给用户
    NSString* orderName = @"微信支付测试";
    //订单金额,单位（分）
    NSString* orderPrice = price;//以分为单位的整数
    
    //    //支付设备号或门店号
    NSString* orderDevice = device;
    
    //支付类型，固定为APP
    NSString* orderType = @"APP";
    //发器支付的机器ip,暂时没有发现其作用
    NSString* orderIP = [self getIP:YES];
    NSLog(@"---%@",orderIP);
    
    //随机数串
    srand( (unsigned)time(0) );
    NSString *noncestr  = [NSString stringWithFormat:@"%d", rand()];
    NSString *orderNO   = [self timeStamp];//订单号。(随机的可以直接用时间戳)
    NSLog(@"orderNO===%@",orderNO);
    
    //================================
    //预付单参数订单设置
    //================================
    NSMutableDictionary *packageParams = [NSMutableDictionary dictionary];
    
    [packageParams setObject: APP_KEY  forKey:@"appid"];       //开放平台appid
    [packageParams setObject: MCH_ID  forKey:@"mch_id"];      //商户号
    [packageParams setObject: orderDevice  forKey:@"device_info"]; //支付设备号或门店号
    [packageParams setObject: noncestr     forKey:@"nonce_str"];   //随机串
    [packageParams setObject: orderType    forKey:@"trade_type"];  //支付类型，固定为APP
    [packageParams setObject: orderName    forKey:@"body"];        //订单描述，展示给用户
    NSString * str = @"www.baidu.com";//[NSString stringWithFormat:@"%@",[payDic objectForKey:@"notify_url"]];
    [packageParams setObject: str  forKey:@"notify_url"];  //支付结果异步通知
    [packageParams setObject: orderNO      forKey:@"out_trade_no"];//商户订单号
    [packageParams setObject: orderIP      forKey:@"spbill_create_ip"];//发器支付的机器ip
    [packageParams setObject: orderPrice   forKey:@"total_fee"];       //订单金额，单位为分
    
    
    /***************************************************  统一下单，获取到prepay_id     ********************************************************************/
    NSString * prePayID = [self getPrePayId:packageParams];
    /***************************************************  获取到prepayid后进行第二次签名  ********************************************************************/
    //获取到prepayid后进行第二次签名
    NSString    *package, *time_stamp, *nonce_str;
    //设置支付参数
    time_t now;
    time(&now);
    time_stamp  = [NSString stringWithFormat:@"%ld", now];//时间戳
    nonce_str = [self md5:time_stamp];//随机字符串（直接用时间戳来生成就可以了）
    
    //重新按提交格式组包，微信客户端暂只支持package=Sign=WXPay格式，须考虑升级后支持携带package具体参数的情况
    //package       = [NSString stringWithFormat:@"Sign=%@",package];
    package         = @"Sign=WXPay";//一般来说是固定的，不需要做任何修改
    
    NSMutableDictionary *signParams = [NSMutableDictionary dictionary];//用于二次签名的参数
    [signParams setObject: APP_KEY  forKey:@"appid"];
    [signParams setObject: MCH_ID  forKey:@"partnerid"];
    [signParams setObject: nonce_str    forKey:@"noncestr"];
    [signParams setObject: package      forKey:@"package"];
    [signParams setObject: time_stamp   forKey:@"timestamp"];
    [signParams setObject: prePayID     forKey:@"prepayid"];
    
    //调起微信支付
    PayReq* req             = [[PayReq alloc] init];
    req.partnerId           = MCH_ID;
    req.prepayId            = prePayID;
    req.nonceStr            = nonce_str;
    req.timeStamp           = time_stamp.intValue;
    req.package             = package;
    
    req.sign                = [self createMd5Sign:signParams];//二次签名
    
    [WXApi sendReq:req];
    
}
-(NSString *)timeStamp{
    return [NSString stringWithFormat:@"%ld",(long)[[NSDate date] timeIntervalSince1970]];
}
#pragma mark ---  获取prePayid
-(NSString *)getPrePayId:(NSMutableDictionary *)pakeParams{
    NSString *prepayid = nil;
    //获取提交支付
    NSString *send = [self genPackage:pakeParams];
    //发送请求post xml数据
    NSData *res = [self httpSend:HTTP method:@"POST" data:send];
    
    XMLHelper *xml  = [[XMLHelper alloc] init];
    
    //开始解析
    [xml startParse:res];
    NSMutableDictionary *resParams = [xml getDict];
    NSLog(@"%@",resParams);
    //判断返回
    NSString *return_code   = [resParams objectForKey:@"return_code"];
    NSString *result_code   = [resParams objectForKey:@"result_code"];
    if ([return_code isEqualToString:@"SUCCESS"]) {
        //生成返回数据进行排序签名
        NSString *sign      = [self createMd5Sign:resParams ];
        NSString *send_sign =[resParams objectForKey:@"sign"];
        if ([sign isEqualToString:send_sign]) {
            if ([result_code isEqualToString:@"SUCCESS"]) {
                prepayid = [resParams objectForKey:@"prepay_id"];
            }
        }
    }
    
    return prepayid;
}
#pragma mark ---  获取package带参数的签名包
-(NSString *)genPackage:(NSMutableDictionary*)packageParams
{
    NSString *sign;
    NSMutableString *reqPars=[NSMutableString string];
    //生成签名
    sign = [self createMd5Sign:packageParams];
    //生成xml的package
    NSArray *keys = [packageParams allKeys];
    [reqPars appendString:@"<xml>\n"];
    for (NSString *categoryId in keys) {
        [reqPars appendFormat:@"<%@>%@</%@>\n", categoryId, [packageParams objectForKey:categoryId],categoryId];
    }
    [reqPars appendFormat:@"<sign>%@</sign>\n</xml>", sign];
    
    return [NSString stringWithString:reqPars];
}
#pragma mark ---  创建package签名
-(NSString*) createMd5Sign:(NSMutableDictionary*)dict
{
    NSMutableString *contentString  =[NSMutableString string];
    NSArray *keys = [dict allKeys];
    //按字母顺序排序
    NSArray *sortedArray = [keys sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2 options:NSNumericSearch];
    }];
    //拼接字符串
    for (NSString *categoryId in sortedArray) {
        if (   ![[dict objectForKey:categoryId] isEqualToString:@""]
            && ![categoryId isEqualToString:@"sign"]
            && ![categoryId isEqualToString:@"key"]
            )
        {
            [contentString appendFormat:@"%@=%@&", categoryId, [dict objectForKey:categoryId]];
        }
        
    }
    //添加key字段
    [contentString appendFormat:@"key=%@", API_KEY];
    NSLog(@"%@",contentString);
    //得到MD5 sign签名
    NSString *md5Sign =[self md5:contentString];
    
    //输出Debug Info
    //    [self.debugInfo appendFormat:@"MD5签名字符串：\n%@\n\n",contentString];
    
    return md5Sign;
}
#pragma mark ---  将字符串进行MD5加密，返回加密后的字符串
-(NSString *) md5:(NSString *)str
{
    const char *cStr = [str UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, (unsigned int)strlen(cStr), digest );
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02X", digest[i]];
    
    return output;
}
#pragma mark ---  http 请求
-(NSData *) httpSend:(NSString *)url method:(NSString *)method data:(NSString *)data
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5];
    //设置提交方式
    [request setHTTPMethod:method];
    //设置数据类型
    [request addValue:@"text/xml" forHTTPHeaderField:@"Content-Type"];
    //设置编码
    [request setValue:@"UTF-8" forHTTPHeaderField:@"charset"];
    //如果是POST
    [request setHTTPBody:[data dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSError *error;
    //将请求的url数据放到NSData对象中
    NSData *response = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
    return response;
    //return [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
}

#pragma mark ---  获取IP
-(NSString *)getIP:(BOOL)preferIPv4{
    NSArray *searchArray = preferIPv4 ?
    @[ IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6 ] :
    @[ IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4 ] ;
    
    NSDictionary *addresses = [self getIPAddresses];
    //NSLog(@"addresses: %@", addresses);
    
    __block NSString *address;
    [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
     {
         address = addresses[key];
         if(address) *stop = YES;
     } ];
    return address ? address : @"0.0.0.0";
    return nil;
}
- (NSDictionary *)getIPAddresses
{
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) || (interface->ifa_flags & IFF_LOOPBACK)) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                char addrBuf[INET6_ADDRSTRLEN];
                if(inet_ntop(addr->sin_family, &addr->sin_addr, addrBuf, sizeof(addrBuf))) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, addr->sin_family == AF_INET ? IP_ADDR_IPv4 : IP_ADDR_IPv6];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    //     The dictionary keys have the form "interface" "/" "ipv4 or ipv6"
    
    return [addresses count] ? addresses : nil;
}

@end
