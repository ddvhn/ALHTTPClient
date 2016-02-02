//
//  ViewController.m
//  ALHTTPClient
//
//  Created by Denis Dovgan on 2/3/16.
//  Copyright © 2016 Denis Dovgan. All rights reserved.
//

#import "ViewController.h"

#import "ALHTTPClient.h"

@import DAAlertController;

@interface ViewController () {

	__weak IBOutlet UIActivityIndicatorView *_activityIndicator;
	__weak IBOutlet UIButton *_sendButton;
	__weak IBOutlet UIButton *_cancelButton;
	
	id<ALHTTPRequest> _httpRequest;
}

@end

@implementation ViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

#pragma mark - User Actions

- (IBAction)sendRequestTapped:(id)sender {

	if (_httpRequest == nil) {
		
		NSString *urlString = @"https://api.myjson.com/bins/26bnd";
		
		__weak typeof(self) welf = self;
		_httpRequest = [[ALHTTPClient shared] requestWithUrl:urlString headers:nil params:nil type:ALRequestTypeGET
			callback:^(id<ALHTTPRequest> request, id response, NSError *error) {
				
				__strong typeof(self) sself = welf;
				if (sself != nil) {
					sself->_httpRequest = nil;
					[sself->_activityIndicator stopAnimating];

					DAAlertAction *okAction = [DAAlertAction actionWithTitle:@"OK" style:DAAlertActionStyleDefault
						handler:nil];

					NSString *alertMessage = nil;

					if (error == nil) {
						alertMessage = [NSString stringWithFormat:@"%@", response];
					} else {
						alertMessage = error.localizedDescription;
					}
					
					NSString *alertTitle = error != nil ? @"Error" : @"Success";
					[DAAlertController showAlertViewInViewController:welf withTitle:alertTitle message:alertMessage
						actions:@[okAction]];
				}
		}];
		
		[_httpRequest start];
		[_activityIndicator startAnimating];
	}
}

- (IBAction)cancelRequestTapped:(id)sender {

	[_httpRequest cancel];
}

@end
