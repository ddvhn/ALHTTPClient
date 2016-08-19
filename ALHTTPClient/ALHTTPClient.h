//
//  ALRequestOperationManager.h
//
//
//  Created by Denis Dovgan on 12/9/15.
//  Copyright © 2015. All rights reserved.
//

@import Foundation;

#import "ALHTTPRequest.h"

typedef void(^ALRequestCallback)(id<ALHTTPRequest> request, id response, NSError *error);

@interface ALHTTPClient : NSObject

@property (nonatomic, assign) NSTimeInterval timeout;

+ (instancetype)shared;

- (id <ALHTTPRequest>)requestWithUrl:(NSString *)url params:(NSDictionary *)params type:(ALRequestType)requestType
	callback:(ALRequestCallback)callback;

- (id <ALHTTPRequest>)requestWithUrl:(NSString *)url headers:(NSDictionary *)headers params:(NSDictionary *)params type:(ALRequestType)requestType
	callback:(ALRequestCallback)callback;

- (id <ALHTTPRequest>)requestWithUrl:(NSString *)url headers:(NSDictionary *)headers params:(NSDictionary *)params type:(ALRequestType)requestType
	requestSerializerType:(ALRequestSerializerType)requestSerializerType callback:(ALRequestCallback)callback;

@end
