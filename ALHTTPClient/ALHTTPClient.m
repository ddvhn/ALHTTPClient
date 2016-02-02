//
//  ALRequestOperationManager.m
//  ALPA
//
//  Created by Denis Dovgan on 12/9/15.
//  Copyright © 2015 Factorial Complexity. All rights reserved.
//

#import "ALHTTPClient.h"

@import AFNetworking;

@class ALHTTPRequestOperation;

typedef void(^AFNetworkingSuccessBlock)(AFHTTPRequestOperation * _Nonnull, id  _Nonnull);
typedef void(^AFNetworkingFailureBlock)(AFHTTPRequestOperation * _Nullable, NSError * _Nonnull);
typedef void(^ALOnRequestFinishedBlock)(id<ALHTTPRequest> request);
typedef AFHTTPRequestOperation* (^ALRequestOnStartBlock)(AFNetworkingSuccessBlock, AFNetworkingFailureBlock);

#pragma mark -
@interface ALHTTPRequestOperation : NSObject <ALHTTPRequest> {
	
	ALRequestOnStartBlock _onStartBlock;
	AFNetworkingSuccessBlock _successBlock;
	AFNetworkingFailureBlock _failureBlock;
	ALOnRequestFinishedBlock _onRequestFinishedBlock;
	
	AFHTTPRequestOperation *_operation;
	
	BOOL _finished;
}

- (instancetype)initWithOnStartBlock:(ALRequestOnStartBlock)block successBlock:(AFNetworkingSuccessBlock)successBlock
	failureBlock:(AFNetworkingFailureBlock)failureBlock onRequestFinishedBlock:(ALOnRequestFinishedBlock)onRequestFinishedBlock;

@end

@implementation ALHTTPRequestOperation

#pragma mark - Init

- (instancetype)initWithOnStartBlock:(ALRequestOnStartBlock)block successBlock:(AFNetworkingSuccessBlock)successBlock
	failureBlock:(AFNetworkingFailureBlock)failureBlock onRequestFinishedBlock:(ALOnRequestFinishedBlock)onRequestFinishedBlock {

	self = [super init];
	if (self) {
		_onStartBlock = block;
		_successBlock = successBlock;
		_failureBlock = failureBlock;
		_onRequestFinishedBlock = onRequestFinishedBlock;
		
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
		_operation = _onStartBlock(_successBlock, _failureBlock);
		
		__weak typeof(self) welf = self;
		[_operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation * _Nonnull operation, id  _Nonnull responseObject) {
			__strong typeof(self) sself = welf;
			if (sself != nil) {
				[sself finish];
				if (sself->_successBlock != nil) {
					sself->_successBlock(operation, responseObject);
				}
			}
		} failure:^(AFHTTPRequestOperation * _Nonnull operation, NSError * _Nonnull error) {
			__strong typeof(self) sself = welf;
			if (sself != nil) {
				[sself finish];
				if (sself->_failureBlock != nil) {
					sself->_failureBlock(operation, error);
				}
			}
		}];
	}
}

- (void)cancel {

	if (!_finished && [self running]) {
		[_operation cancel];
	}
}

- (BOOL)running {

	return _operation != nil;
}

- (BOOL)finished {
	
	return _finished;
}

- (void)finish {
	
	NSAssert([self running] == YES && _finished == NO, @"Unexpected state");
	
	_operation = nil;
	_finished = YES;
	
	if (_onRequestFinishedBlock != nil) {
		_onRequestFinishedBlock(self);
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
		[self setupManager];
	}
	
	return self;
}

- (void)setupManager {

	AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
	manager.responseSerializer = [AFJSONResponseSerializer serializer];
}

#pragma mark - Common Code

- (id <ALHTTPRequest>)requestWithUrl:(NSString *)url params:(NSDictionary *)params type:(ALRequestType)requestType
	callback:(ALRequestOperationCallback)callback {

	return [self requestWithUrl:url headers:nil params:params type:requestType callback:callback];
}

- (id <ALHTTPRequest>)requestWithUrl:(NSString *)url headers:(NSDictionary *)headers params:(NSDictionary *)params
	type:(ALRequestType)requestType callback:(ALRequestOperationCallback)callback {

	return [self requestWithUrl:url headers:headers params:params type:requestType requestSerializerType:ALRequestSerializerTypeDEFAULT
		callback:callback];
}

- (id <ALHTTPRequest>)requestWithUrl:(NSString *)url headers:(NSDictionary *)headers params:(NSDictionary *)params type:(ALRequestType)requestType
	requestSerializerType:(ALRequestSerializerType)requestSerializerType callback:(ALRequestOperationCallback)callback {
	
	AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];

	AFHTTPRequestSerializer *requestSerializer = requestSerializerType == ALRequestSerializerTypeDEFAULT ?
		[AFHTTPRequestSerializer serializer] : [AFJSONRequestSerializer serializer];
	[headers enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSString *_Nonnull value, BOOL * _Nonnull stop) {
		[requestSerializer setValue:value forHTTPHeaderField:key];
	}];
	requestSerializer.timeoutInterval = 30.f;
	manager.requestSerializer = requestSerializer;
	
	__weak __block id<ALHTTPRequest> weakRequestOperation = nil;

	void (^requestSuccessBlock)(AFHTTPRequestOperation * _Nonnull, id  _Nonnull) = ^(AFHTTPRequestOperation * _Nonnull operation, id  _Nonnull responseObject) {
		callback(weakRequestOperation, responseObject, nil);
	};
	
	void (^requestFailureBlock)(AFHTTPRequestOperation * _Nullable, NSError * _Nonnull) = ^(AFHTTPRequestOperation * _Nullable operation, NSError * _Nonnull error) {
		callback(weakRequestOperation, nil, error);
	};
	
	__weak typeof(self) welf = self;
	ALOnRequestFinishedBlock onRequestFinishedBlock = ^(id <ALHTTPRequest> request) {
		__strong typeof(self) sself = welf;
		if (sself != nil) {
			[sself->_requestsPool removeObject:request];
		}
	};

	id<ALHTTPRequest> requestOperation = nil;
	
	switch (requestType) {
	
		case ALRequestTypePOST: {
			
			requestOperation = [[ALHTTPRequestOperation alloc]
				initWithOnStartBlock:^AFHTTPRequestOperation *(AFNetworkingSuccessBlock aSuccessBlock, AFNetworkingFailureBlock aFailureBlock) {
					return [manager POST:url parameters:params success:aSuccessBlock failure:aFailureBlock];
			} successBlock:requestSuccessBlock failureBlock:requestFailureBlock onRequestFinishedBlock:onRequestFinishedBlock];
		}
			break;
			
		case ALRequestTypeGET: {
			
			requestOperation = [[ALHTTPRequestOperation alloc]
				initWithOnStartBlock:^AFHTTPRequestOperation *(AFNetworkingSuccessBlock aSuccessBlock, AFNetworkingFailureBlock aFailureBlock) {
					return [manager GET:url parameters:params success:aSuccessBlock failure:aFailureBlock];
			} successBlock:requestSuccessBlock failureBlock:requestFailureBlock onRequestFinishedBlock:onRequestFinishedBlock];
		}
			break;
			
		case ALRequestTypeDELETE: {

			requestOperation = [[ALHTTPRequestOperation alloc]
				initWithOnStartBlock:^AFHTTPRequestOperation *(AFNetworkingSuccessBlock aSuccessBlock, AFNetworkingFailureBlock aFailureBlock) {
					return [manager DELETE:url parameters:params success:aSuccessBlock failure:aFailureBlock];
			} successBlock:requestSuccessBlock failureBlock:requestFailureBlock onRequestFinishedBlock:onRequestFinishedBlock];
		}
			break;
			
		case ALRequestTypePUT: {
			requestOperation = [[ALHTTPRequestOperation alloc]
				initWithOnStartBlock:^AFHTTPRequestOperation *(AFNetworkingSuccessBlock aSuccessBlock, AFNetworkingFailureBlock aFailureBlock) {
					return [manager PUT:url parameters:params success:aSuccessBlock failure:aFailureBlock];
			} successBlock:requestSuccessBlock failureBlock:requestFailureBlock onRequestFinishedBlock:onRequestFinishedBlock];
		}
			break;
			
		case ALRequestTypePATCH: {
			requestOperation = [[ALHTTPRequestOperation alloc]
				initWithOnStartBlock:^AFHTTPRequestOperation *(AFNetworkingSuccessBlock aSuccessBlock, AFNetworkingFailureBlock aFailureBlock) {
					return [manager PATCH:url parameters:params success:aSuccessBlock failure:aFailureBlock];
			} successBlock:requestSuccessBlock failureBlock:requestFailureBlock onRequestFinishedBlock:onRequestFinishedBlock];
		}
			break;
			
		default:
			break;
	}
	
	weakRequestOperation = requestOperation;
	[_requestsPool addObject:requestOperation];
	
	return requestOperation;
}

@end
