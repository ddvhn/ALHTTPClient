//
//  ALRequestOperationManager.m
//
//
//  Created by Denis Dovgan on 12/9/15.
//  Copyright © 2015. All rights reserved.
//

#import "ALHTTPClient.h"

static const NSTimeInterval kDefaultTimeoutInterval = 30.f;

@import AFNetworking;

@class ALHTTPRequestOperation;

typedef void(^AFNetworkingSuccessBlock)(NSURLSessionDataTask * _Nonnull task, id  _Nonnull response);
typedef void(^AFNetworkingFailureBlock)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error);
typedef void(^ALHTTPRequestFinishBlock)(id<ALHTTPRequest> request);
typedef NSURLSessionDataTask* (^ALRequestOnStartBlock)(AFNetworkingSuccessBlock successBlock, AFNetworkingFailureBlock failureBlock);

#pragma mark -
@interface ALHTTPRequestTask : NSObject <ALHTTPRequest> {
	
	ALRequestOnStartBlock _onStartBlock;
	AFNetworkingSuccessBlock _successBlock;
	AFNetworkingFailureBlock _failureBlock;
	ALHTTPRequestFinishBlock _finishBlock;
	
	NSURLSessionDataTask *_task;
	
	BOOL _finished;
}

- (instancetype)initWithOnStartBlock:(ALRequestOnStartBlock)onStartBlock successBlock:(AFNetworkingSuccessBlock)successBlock
	failureBlock:(AFNetworkingFailureBlock)failureBlock finishBlock:(ALHTTPRequestFinishBlock)finishBlock;

@end

@implementation ALHTTPRequestTask

#pragma mark - Init

- (instancetype)initWithOnStartBlock:(ALRequestOnStartBlock)onStartBlock successBlock:(AFNetworkingSuccessBlock)successBlock
	failureBlock:(AFNetworkingFailureBlock)failureBlock finishBlock:(ALHTTPRequestFinishBlock)finishBlock {
	
	self = [super init];
	if (self) {
		_onStartBlock = onStartBlock;
		_successBlock = successBlock;
		_failureBlock = failureBlock;
		_finishBlock = finishBlock;
		
		_finished = NO;
	}
	
	return self;
}

- (void)dealloc {
/*
	NSLog(@"id <ALHTTPRequest> %@ deallocated", self);
*/
}

#pragma mark - Common Code

- (void)start {

	BOOL canStart = _finished != YES && [self running] != YES;
	if (canStart) {
	
		__weak typeof(self) welf = self;
		AFNetworkingSuccessBlock successBlock = ^void(NSURLSessionDataTask * _Nonnull task, id  _Nonnull response) {
			__strong typeof(self) sself = welf;
			if (sself != nil) {
				[sself finish];
				if (sself->_successBlock != nil) {
					sself->_successBlock(task, response);
				}
			}
		};
		
		AFNetworkingFailureBlock failureBlock = ^void(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
			__strong typeof(self) sself = welf;
			if (sself != nil) {
				[sself finish];
				if (sself->_failureBlock != nil) {
					sself->_failureBlock(task, error);
				}
			}
		};
		_task = _onStartBlock(successBlock, failureBlock);
	}
}

- (void)cancel {

	if (!_finished && [self running]) {
		[_task cancel];
	}
}

- (BOOL)running {

	return _task != nil;
}

- (BOOL)finished {
	
	return _finished;
}

- (void)finish {
	
	NSAssert([self running] == YES && _finished == NO, @"Unexpected state");
	
	_task = nil;
	_finished = YES;
	
	if (_finishBlock != nil) {
		_finishBlock(self);
	}
}

@end

#pragma mark -

@interface ALHTTPClient () {
	
	NSMutableArray<id<ALHTTPRequest>> *_requestsPool;
}

@end


@implementation ALHTTPClient

#pragma mark - Init

+ (instancetype)shared {
	
	static ALHTTPClient *_instance = nil;
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		_instance = [self new];
	});
	
    return _instance;
}

- (instancetype)init {
	
	self = [super init];
	if (self) {
		_requestsPool = [NSMutableArray new];
		[self setup];
	}
	
	return self;
}

- (void)setup {

	_timeout = kDefaultTimeoutInterval;
}

#pragma mark - Setters

- (void)setTimeout:(NSTimeInterval)timeout {
	
	if (timeout > 0) {
		_timeout = timeout;
	}
}

#pragma mark - Common Code

- (id <ALHTTPRequest>)requestWithUrl:(NSString *)url params:(NSDictionary *)params type:(ALRequestType)requestType
	callback:(ALRequestCallback)callback {

	return [self requestWithUrl:url headers:nil params:params type:requestType callback:callback];
}

- (id <ALHTTPRequest>)requestWithUrl:(NSString *)url headers:(NSDictionary *)headers params:(NSDictionary *)params
	type:(ALRequestType)requestType callback:(ALRequestCallback)callback {

	return [self requestWithUrl:url headers:headers params:params type:requestType requestSerializerType:ALRequestSerializerTypeDEFAULT
		callback:callback];
}

- (id <ALHTTPRequest>)requestWithUrl:(NSString *)url headers:(NSDictionary *)headers params:(NSDictionary *)params type:(ALRequestType)requestType
	requestSerializerType:(ALRequestSerializerType)requestSerializerType callback:(ALRequestCallback)callback {
	
	AFHTTPRequestSerializer *requestSerializer = requestSerializerType == ALRequestSerializerTypeDEFAULT ?
		[AFHTTPRequestSerializer serializer] : [AFJSONRequestSerializer serializer];
	[headers enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSString *_Nonnull value, BOOL * _Nonnull stop) {
		[requestSerializer setValue:value forHTTPHeaderField:key];
	}];
	requestSerializer.timeoutInterval = _timeout;
	
	AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
	manager.responseSerializer = [AFJSONResponseSerializer serializer];
	manager.requestSerializer = requestSerializer;
	
	__weak __block id<ALHTTPRequest> weakRequest = nil;
	AFNetworkingSuccessBlock commonRequestSuccessBlock = ^(NSURLSessionDataTask * _Nonnull operation, id _Nonnull responseObject) {
		callback(weakRequest, responseObject, nil);
	};
	
	AFNetworkingFailureBlock commonRequestFailureBlock = ^(NSURLSessionDataTask * _Nullable operation, NSError * _Nonnull error) {
		callback(weakRequest, nil, error);
	};
	
	__weak typeof(self) welf = self;
	ALHTTPRequestFinishBlock commonRequestFinishBlock = ^void(id<ALHTTPRequest> request) {
		__strong typeof(self) sself = welf;
		if (sself != nil) {
			[sself->_requestsPool removeObject:request];
		}
	};
	
	id<ALHTTPRequest> request = nil;
	
	switch (requestType) {
	
		case ALRequestTypePOST: {
			
			request = [[ALHTTPRequestTask alloc] initWithOnStartBlock:^NSURLSessionDataTask *(AFNetworkingSuccessBlock successBlock, AFNetworkingFailureBlock failureBlock) {
				return [manager POST:url parameters:params progress:nil success:successBlock failure:failureBlock];
			} successBlock:commonRequestSuccessBlock failureBlock:commonRequestFailureBlock finishBlock:commonRequestFinishBlock];
		}
			break;
			
		case ALRequestTypeGET: {
			
			request = [[ALHTTPRequestTask alloc] initWithOnStartBlock:^NSURLSessionDataTask *(AFNetworkingSuccessBlock successBlock, AFNetworkingFailureBlock failureBlock) {
				return [manager GET:url parameters:params progress:nil success:successBlock failure:failureBlock];
			} successBlock:commonRequestSuccessBlock failureBlock:commonRequestFailureBlock finishBlock:commonRequestFinishBlock];
		}
			break;
			
		case ALRequestTypeDELETE: {

			request = [[ALHTTPRequestTask alloc] initWithOnStartBlock:^NSURLSessionDataTask *(AFNetworkingSuccessBlock successBlock, AFNetworkingFailureBlock failureBlock) {
				return [manager DELETE:url parameters:params success:successBlock failure:failureBlock];
			} successBlock:commonRequestSuccessBlock failureBlock:commonRequestFailureBlock finishBlock:commonRequestFinishBlock];
		}
			break;

		case ALRequestTypePUT: {
		
			request = [[ALHTTPRequestTask alloc] initWithOnStartBlock:^NSURLSessionDataTask *(AFNetworkingSuccessBlock successBlock, AFNetworkingFailureBlock failureBlock) {
				return [manager PUT:url parameters:params success:successBlock failure:failureBlock];
			} successBlock:commonRequestSuccessBlock failureBlock:commonRequestFailureBlock finishBlock:commonRequestFinishBlock];
		}
			break;

		case ALRequestTypePATCH: {
		
			request = [[ALHTTPRequestTask alloc] initWithOnStartBlock:^NSURLSessionDataTask *(AFNetworkingSuccessBlock successBlock, AFNetworkingFailureBlock failureBlock) {
				return [manager PUT:url parameters:params success:successBlock failure:failureBlock];
			} successBlock:commonRequestSuccessBlock failureBlock:commonRequestFailureBlock finishBlock:commonRequestFinishBlock];
		}
			break;
			
		default:
			break;
	}
	
	weakRequest = request;
	[_requestsPool addObject:request];

	return request;
}

@end