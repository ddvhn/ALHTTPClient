//
//  ALRequestOperationManager.h
//  ALPA
//
//  Created by Denis Dovgan on 12/9/15.
//  Copyright © 2015 Factorial Complexity. All rights reserved.
//

@import Foundation;

#import "ALHTTPRequest.h"

typedef void(^ALRequestOperationCallback)(id<ALHTTPRequest> request, id response, NSError *error);

@interface ALHTTPClient : NSObject

+ (instancetype)shared;

- (id <ALHTTPRequest>)requestWithUrl:(NSString *)url params:(NSDictionary *)params type:(ALRequestType)requestType
	callback:(ALRequestOperationCallback)callback;

- (id <ALHTTPRequest>)requestWithUrl:(NSString *)url headers:(NSDictionary *)headers params:(NSDictionary *)params type:(ALRequestType)requestType
	callback:(ALRequestOperationCallback)callback;

- (id <ALHTTPRequest>)requestWithUrl:(NSString *)url headers:(NSDictionary *)headers params:(NSDictionary *)params type:(ALRequestType)requestType
	requestSerializerType:(ALRequestSerializerType)requestSerializerType callback:(ALRequestOperationCallback)callback;

@end
