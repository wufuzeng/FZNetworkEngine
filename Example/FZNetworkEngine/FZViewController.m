//
//  FZViewController.m
//  FZNetworkEngine
//
//  Created by wufuzeng on 06/24/2019.
//  Copyright (c) 2019 wufuzeng. All rights reserved.
//

#import "FZViewController.h"

#import <FZNetworkEngine/FZNetworkEngine.h>

@interface FZViewController ()

@end

@implementation FZViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    
    NSString *url = @"http://api.map.baidu.com/telematics/v3/weather";
    
    [[FZNetworkEngine shareNetwork] method:GET_METHOD url:url params:@{
                                                                       //location=嘉兴&output=json&ak=5slgyqGDENN7Sy7pw29IUvrZ
                                                                       @"location":@"嘉兴",
                                                                       @"output":@"json",
                                                                       @"ak":@"5slgyqGDENN7Sy7pw29IUvrZ",
                                                                       //@"":@"",
                                                                       }
                                 keepFirst:YES
                               libraryType:LibraryTypeAFN
                               headerfield:nil
                                  progress:nil
                                    finish:^(NSDictionary * _Nullable responseDict, NSError * _Nullable error) {
       
        NSLog(@"%@",responseDict);
         
    }];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
