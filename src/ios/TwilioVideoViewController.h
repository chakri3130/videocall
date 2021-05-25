//
//  TwilioVideoViewController.h
//
//  Copyright © 2016-2017 Twilio, Inc. All rights reserved.
//

@import UIKit;

@protocol TwilioVideoCalldelegate <NSObject>

-(void)didEndcall;

@end

@interface TwilioVideoViewController : UIViewController

@property (nonatomic, strong) NSString *accessToken;
@property (nonatomic, strong) id <TwilioVideoCalldelegate> delegate_call;

- (void)connectToRoom:(NSString*)room ;

@end
