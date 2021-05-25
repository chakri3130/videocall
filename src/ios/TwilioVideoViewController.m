//
//  TwilioVideoViewController.m
//
//  Copyright © 2016-2017 Twilio, Inc. All rights reserved.
//

@import TwilioVideo;
#import "TwilioVideoViewController.h"
#import <Foundation/Foundation.h>

@interface PlatformUtils : NSObject

+ (BOOL)isSimulator;

@end

@implementation PlatformUtils

+ (BOOL)isSimulator {
#if TARGET_IPHONE_SIMULATOR
    return YES;
#endif
    return NO;
}

@end

@interface TwilioVideoViewController () <UITextFieldDelegate, TVIRemoteParticipantDelegate, TVIRoomDelegate, TVIVideoViewDelegate, TVICameraSourceDelegate>

#pragma mark Video SDK components

@property (nonatomic, strong) TVICameraSource *camera;
@property (nonatomic, strong) TVILocalVideoTrack *localVideoTrack;
@property (nonatomic, strong) TVILocalAudioTrack *localAudioTrack;
@property (nonatomic, strong) TVIRemoteParticipant *remoteParticipant;
@property (nonatomic, weak) TVIVideoView *remoteView;
@property (nonatomic, strong) TVIRoom *room;

#pragma mark UI Element Outlets and handles



// `TVIVideoView` created from a storyboard
@property (weak, nonatomic) IBOutlet TVIVideoView *previewView;

@property (nonatomic, weak) IBOutlet UIButton *disconnectButton;
@property (nonatomic, weak) IBOutlet UILabel *messageLabel;
@property (nonatomic, weak) IBOutlet UIButton *micButton;
@property (nonatomic, weak) IBOutlet UIButton *flipCameraButton;
@property (nonatomic, weak) IBOutlet UIButton *videoButton;

@end

@implementation TwilioVideoViewController

- (void)dealloc {
    // We are done with camera
    if (self.camera) {
        [self.camera stopCapture];
        self.camera = nil;
    }
}

#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self logMessage:[NSString stringWithFormat:@"TwilioVideo v%@", [TwilioVideoSDK version]]];

    // Configure access token manually for testing, if desired! Create one manually in the console
    //  self.accessToken = @"TWILIO_ACCESS_TOKEN";


    // Preview our local camera track in the local video preview view.
    [self startPreview];

    // Disconnect and mic button will be displayed when client is connected to a room.
    // self.disconnectButton.hidden = YES;
    // self.micButton.hidden = YES;

    // JDavis: fix error
    // UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    // [self.view addGestureRecognizer:tap];
}

#pragma mark - Public

- (void)connectToRoom:(NSString*)room {
    [self showRoomUI:YES];
    if ([self.accessToken isEqualToString:@"TWILIO_ACCESS_TOKEN"]) {
        [self logMessage:[NSString stringWithFormat:@"Fetching an access token"]];
        [self showRoomUI:NO];
    } else {
        [self doConnect:room];
    }
}

- (IBAction)disconnectButtonPressed:(id)sender {
    [self.room disconnect];
    [_delegate_call didEndcall];
    [self dismissViewControllerAnimated:true completion:nil];
}

- (IBAction)micButtonPressed:(id)sender {

    // We will toggle the mic to mute/unmute and change the title according to the user action.

    if (self.localAudioTrack) {
        self.localAudioTrack.enabled = !self.localAudioTrack.isEnabled;

        // Toggle the button title
        if (self.localAudioTrack.isEnabled) {
            self.micButton.selected = false;
            self.micButton.alpha = self.micButton.selected ? 0.7 : 1;
            // [self.micButton setTitle:@"Mute" forState:UIControlStateNormal];
        } else {
            // [self.micButton setTitle:@"Unmute" forState:UIControlStateNormal];
            self.micButton.selected = true;
            self.micButton.alpha = self.micButton.selected ? 0.7 : 1;
        }
    }
}

- (IBAction)flipcameraButtonPressed:(id)sender {
    if(self.localVideoTrack){
        //  self.flipCameraButton.selected = !self.flipCameraButton.selected;
        //  self.flipCameraButton.alpha = self.flipCameraButton.selected ? 0.7 : 1;
        [self flipCamera];
    }
}

- (IBAction)videoButtonPressed:(id)sender {
    if(self.localVideoTrack){
        self.localVideoTrack.enabled = !self.localVideoTrack.isEnabled;

        if(self.localVideoTrack.isEnabled){
            self.videoButton.selected=false;
            self.videoButton.alpha = self.videoButton.selected ? 0.7 : 1;
        }else {
            self.videoButton.selected=true;
            self.videoButton.alpha = self.videoButton.selected ? 0.7 : 1;
        }
    }
}

#pragma mark - Private

- (void)startPreview {
    // TVICameraCapturer is not supported with the Simulator.
    // TVICameraSource is not supported with the Simulator.
    if ([PlatformUtils isSimulator]) {
        [self.previewView removeFromSuperview];
        return;
    }

    AVCaptureDevice *frontCamera = [TVICameraSource captureDeviceForPosition:AVCaptureDevicePositionFront];
    AVCaptureDevice *backCamera = [TVICameraSource captureDeviceForPosition:AVCaptureDevicePositionBack];

    if (frontCamera != nil || backCamera != nil) {
        self.camera = [[TVICameraSource alloc] initWithDelegate:(id)self];
        self.localVideoTrack = [TVILocalVideoTrack trackWithSource:self.camera
                                                           enabled:YES
                                                              name:@"Camera"];
        // Add renderer to video track for local preview
        [self.localVideoTrack addRenderer:self.previewView];
        [self logMessage:@"Video track created"];

        if (frontCamera != nil && backCamera != nil) {
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                  action:@selector(flipCamera)];
            [self.previewView addGestureRecognizer:tap];
        }

        [self.camera startCaptureWithDevice:frontCamera != nil ? frontCamera : backCamera
                                 completion:^(AVCaptureDevice *device, TVIVideoFormat *format, NSError *error) {
                                     if (error != nil) {
                                         [self logMessage:[NSString stringWithFormat:@"Start capture failed with error.\ncode = %lu error = %@", error.code, error.localizedDescription]];
                                     } else {
                                         self.previewView.mirror = (device.position == AVCaptureDevicePositionFront);
                                     }
                                 }];
    } else {
        [self logMessage:@"No front or back capture device found!"];
    }

//    if ([PlatformUtils isSimulator]) {
//        [self.previewView removeFromSuperview];
//        return;
//    }
//
//    AVCaptureDevice *frontCamera = [TVICameraSource captureDeviceForPosition:AVCaptureDevicePositionFront];
//    AVCaptureDevice *backCamera = [TVICameraSource captureDeviceForPosition:AVCaptureDevicePositionBack];
//
//    self.camera = [[TVICameraCapturer alloc] initWithSource:TVICameraCaptureSourceFrontCamera delegate:self];
//    self.localVideoTrack = [TVILocalVideoTrack trackWithCapturer:self.camera];
//
//    if (!self.localVideoTrack) {
//        //     [self logMessage:@"Failed to add video track"];
//    } else {
//        // Add renderer to video track for local preview
//        [self.localVideoTrack addRenderer:self.previewView];
//        //    [self logMessage:@"Video track created"];
//
//        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(flipCamera)];
//        [self.previewView addGestureRecognizer:tap];
//    }
}

- (void)flipCamera {
    AVCaptureDevice *newDevice = nil;

    if (self.camera.device.position == AVCaptureDevicePositionFront) {
        newDevice = [TVICameraSource captureDeviceForPosition:AVCaptureDevicePositionBack];
    } else {
        newDevice = [TVICameraSource captureDeviceForPosition:AVCaptureDevicePositionFront];
    }

    if (newDevice != nil) {
        [self.camera selectCaptureDevice:newDevice completion:^(AVCaptureDevice *device, TVIVideoFormat *format, NSError *error) {
            if (error != nil) {
                [self logMessage:[NSString stringWithFormat:@"Error selecting capture device.\ncode = %lu error = %@", error.code, error.localizedDescription]];
            } else {
                self.previewView.mirror = (device.position == AVCaptureDevicePositionFront);
            }
        }];
    }
   /* if (self.camera.source == TVICameraCaptureSourceFrontCamera) {
        [self.camera selectSource:TVICameraCaptureSourceBackCameraWide];
    } else {
        [self.camera selectSource:TVICameraCaptureSourceFrontCamera];
    }*/
}

- (void)prepareLocalMedia {

    // We will share local audio and video when we connect to room.
    // We will share local audio and video when we connect to room.
       
       // Create an audio track.
       if (!self.localAudioTrack) {
           self.localAudioTrack = [TVILocalAudioTrack trackWithOptions:nil
                                                               enabled:YES
                                                                  name:@"Microphone"];

           if (!self.localAudioTrack) {
               [self logMessage:@"Failed to add audio track"];
           }
       }

       // Create a video track which captures from the camera.
       if (!self.localVideoTrack) {
           [self startPreview];
       }/*
    // Create an audio track.
    if (!self.localAudioTrack) {
        self.localAudioTrack = [TVILocalAudioTrack track];

        if (!self.localAudioTrack) {
            //         [self logMessage:@"Failed to add audio track"];
        }
    }

    // Create a video track which captures from the camera.
    if (!self.localVideoTrack) {
        [self startPreview];
    }*/
}

- (void)doConnect:(NSString*)room {
    if ([self.accessToken isEqualToString:@"TWILIO_ACCESS_TOKEN"]) {
        //   [self logMessage:@"Please provide a valid token to connect to a room"];
        return;
    }
    // Prepare local media which we will share with Room Participants.
    [self prepareLocalMedia];

    TVIConnectOptions *connectOptions = [TVIConnectOptions optionsWithToken:self.accessToken
                                                                      block:^(TVIConnectOptionsBuilder * _Nonnull builder) {

                                                                          // Use the local media that we prepared earlier.
                                                                          builder.audioTracks = self.localAudioTrack ? @[ self.localAudioTrack ] : @[ ];
                                                                          builder.videoTracks = self.localVideoTrack ? @[ self.localVideoTrack ] : @[ ];

                                                                          // The name of the Room where the Client will attempt to connect to. Please note that if you pass an empty
                                                                          // Room `name`, the Client will create one for you. You can get the name or sid from any connected Room.
                                                                          builder.roomName = room;
                                                                      }];

    // Connect to the Room using the options we provided.
    self.room = [TwilioVideoSDK connectWithOptions:connectOptions delegate:self];

    //   [self logMessage:[NSString stringWithFormat:@"Attempting to connect to room %@", room]];
}

- (void)setupRemoteView {
    // Creating `TVIVideoView` programmatically
    TVIVideoView *remoteView = [[TVIVideoView alloc] init];

    // `TVIVideoView` supports UIViewContentModeScaleToFill, UIViewContentModeScaleAspectFill and UIViewContentModeScaleAspectFit
    // UIViewContentModeScaleAspectFit is the default mode when you create `TVIVideoView` programmatically.
    self.remoteView.contentMode = UIViewContentModeScaleAspectFit;

    [self.view insertSubview:remoteView atIndex:0];
    self.remoteView = remoteView;

    NSLayoutConstraint *centerX = [NSLayoutConstraint constraintWithItem:self.remoteView
                                                               attribute:NSLayoutAttributeCenterX
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.view
                                                               attribute:NSLayoutAttributeCenterX
                                                              multiplier:1
                                                                constant:0];
    [self.view addConstraint:centerX];
    NSLayoutConstraint *centerY = [NSLayoutConstraint constraintWithItem:self.remoteView
                                                               attribute:NSLayoutAttributeCenterY
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.view
                                                               attribute:NSLayoutAttributeCenterY
                                                              multiplier:1
                                                                constant:0];
    [self.view addConstraint:centerY];
    NSLayoutConstraint *width = [NSLayoutConstraint constraintWithItem:self.remoteView
                                                             attribute:NSLayoutAttributeWidth
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeWidth
                                                            multiplier:1
                                                              constant:0];
    [self.view addConstraint:width];
    NSLayoutConstraint *height = [NSLayoutConstraint constraintWithItem:self.remoteView
                                                              attribute:NSLayoutAttributeHeight
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.view
                                                              attribute:NSLayoutAttributeHeight
                                                             multiplier:1
                                                               constant:0];
    [self.view addConstraint:height];
}

// Reset the client ui status
- (void)showRoomUI:(BOOL)inRoom {
    // self.micButton.hidden = !inRoom;
    // self.disconnectButton.hidden = !inRoom;
    [UIApplication sharedApplication].idleTimerDisabled = inRoom;
}

- (void)cleanupRemoteParticipant {
    if (self.remoteParticipant) {
           if ([self.remoteParticipant.videoTracks count] > 0) {
               TVIRemoteVideoTrack *videoTrack = self.remoteParticipant.remoteVideoTracks[0].remoteTrack;
               [videoTrack removeRenderer:self.remoteView];
               [self.remoteView removeFromSuperview];
           }
           self.remoteParticipant = nil;
       }
    /*if (self.participant) {
        if ([self.participant.videoTracks count] > 0) {
            [self.participant.videoTracks[0] removeRenderer:self.remoteView];
            [self.remoteView removeFromSuperview];
        }
        self.participant = nil;
    }*/
}

- (void)logMessage:(NSString *)msg {
    NSLog(@"%@", msg);
    self.messageLabel.text = msg;
}

#pragma mark - UITextFieldDelegate
#pragma mark - TVIRoomDelegate

- (void)didConnectToRoom:(TVIRoom *)room {
    // At the moment, this example only supports rendering one Participant at a time.
    
  //  [self logMessage:[NSString stringWithFormat:@"Connected to room %@ as %@", room.name, room.localParticipant.identity]];
    
    if (room.remoteParticipants.count > 0) {
        self.remoteParticipant = room.remoteParticipants[0];
        self.remoteParticipant.delegate = self;
    }
}

- (void)room:(TVIRoom *)room didDisconnectWithError:(nullable NSError *)error {
    [self logMessage:[NSString stringWithFormat:@"Disconncted from room %@, error = %@", room.name, error]];
    
    [self cleanupRemoteParticipant];
    self.room = nil;
    
    [self showRoomUI:NO];
}

- (void)room:(TVIRoom *)room didFailToConnectWithError:(nonnull NSError *)error{
    [self logMessage:[NSString stringWithFormat:@"Failed to connect to room, error = %@", error]];
    
    self.room = nil;
    
    [self showRoomUI:NO];
}

- (void)room:(TVIRoom *)room isReconnectingWithError:(NSError *)error {
    NSString *message = [NSString stringWithFormat:@"Reconnecting due to %@", error.localizedDescription];
    [self logMessage:message];
}

- (void)didReconnectToRoom:(TVIRoom *)room {
    [self logMessage:@"Reconnected to room"];
}

- (void)room:(TVIRoom *)room participantDidConnect:(TVIRemoteParticipant *)participant {
    if (!self.remoteParticipant) {
        self.remoteParticipant = participant;
        self.remoteParticipant.delegate = self;
    }
    [self logMessage:[NSString stringWithFormat:@"Participant %@ connected with %lu audio and %lu video tracks",
                      participant.identity,
                      (unsigned long)[participant.audioTracks count],
                      (unsigned long)[participant.videoTracks count]]];
}

- (void)room:(TVIRoom *)room participantDidDisconnect:(TVIRemoteParticipant *)participant {
    if (self.remoteParticipant == participant) {
        [self cleanupRemoteParticipant];
    }
    [self logMessage:[NSString stringWithFormat:@"Room %@ participant %@ disconnected", room.name, participant.identity]];
    [self logMessage:@"Participant disconnected"];
    
   // [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

#pragma mark - TVIRemoteParticipantDelegate

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
     didPublishVideoTrack:(TVIRemoteVideoTrackPublication *)publication {
    
    // Remote Participant has offered to share the video Track.

    [self logMessage:[NSString stringWithFormat:@"Participant %@ published %@ video track .",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
   didUnpublishVideoTrack:(TVIRemoteVideoTrackPublication *)publication {
    
    // Remote Participant has stopped sharing the video Track.
    
    [self logMessage:[NSString stringWithFormat:@"Participant %@ unpublished %@ video track.",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
     didPublishAudioTrack:(TVIRemoteAudioTrackPublication *)publication {
    
    // Remote Participant has offered to share the audio Track.
    
    [self logMessage:[NSString stringWithFormat:@"Participant %@ published %@ audio track.",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
   didUnpublishAudioTrack:(TVIRemoteAudioTrackPublication *)publication {
    
    // Remote Participant has stopped sharing the audio Track.
    
    [self logMessage:[NSString stringWithFormat:@"Participant %@ unpublished %@ audio track.",
                      participant.identity, publication.trackName]];
}

- (void)didSubscribeToVideoTrack:(TVIRemoteVideoTrack *)videoTrack
                     publication:(TVIRemoteVideoTrackPublication *)publication
                  forParticipant:(TVIRemoteParticipant *)participant {
    
    // We are subscribed to the remote Participant's audio Track. We will start receiving the
    // remote Participant's video frames now.
    
    [self logMessage:[NSString stringWithFormat:@"Subscribed to %@ video track for Participant %@",
                      publication.trackName, participant.identity]];
    
    if (self.remoteParticipant == participant) {
        [self setupRemoteView];
        [videoTrack addRenderer:self.remoteView];
    }
}

- (void)didUnsubscribeFromVideoTrack:(TVIRemoteVideoTrack *)videoTrack
                         publication:(TVIRemoteVideoTrackPublication *)publication
                      forParticipant:(TVIRemoteParticipant *)participant {
    
    // We are unsubscribed from the remote Participant's video Track. We will no longer receive the
    // remote Participant's video.
    
    [self logMessage:[NSString stringWithFormat:@"Unsubscribed from %@ video track for Participant %@",
                      publication.trackName, participant.identity]];
    
    if (self.remoteParticipant == participant) {
        [videoTrack removeRenderer:self.remoteView];
        [self.remoteView removeFromSuperview];
    }
}

- (void)didSubscribeToAudioTrack:(TVIRemoteAudioTrack *)audioTrack
                     publication:(TVIRemoteAudioTrackPublication *)publication
                  forParticipant:(TVIRemoteParticipant *)participant {
    
    // We are subscribed to the remote Participant's audio Track. We will start receiving the
    // remote Participant's audio now.
    
    [self logMessage:[NSString stringWithFormat:@"Subscribed to %@ audio track for Participant %@",
                      publication.trackName, participant.identity]];
}

- (void)didUnsubscribeFromAudioTrack:(TVIRemoteAudioTrack *)audioTrack
                         publication:(TVIRemoteAudioTrackPublication *)publication
                      forParticipant:(TVIRemoteParticipant *)participant {
    
    // We are unsubscribed from the remote Participant's audio Track. We will no longer receive the
    // remote Participant's audio.
    
    [self logMessage:[NSString stringWithFormat:@"Unsubscribed from %@ audio track for Participant %@",
                      publication.trackName, participant.identity]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
      didEnableVideoTrack:(TVIRemoteVideoTrackPublication *)publication {
    [self logMessage:[NSString stringWithFormat:@"Participant %@ enabled %@ video track.",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
     didDisableVideoTrack:(TVIRemoteVideoTrackPublication *)publication {
    [self logMessage:[NSString stringWithFormat:@"Participant %@ disabled %@ video track.",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
      didEnableAudioTrack:(TVIRemoteAudioTrackPublication *)publication {
    [self logMessage:[NSString stringWithFormat:@"Participant %@ enabled %@ audio track.",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
     didDisableAudioTrack:(TVIRemoteAudioTrackPublication *)publication {
    [self logMessage:[NSString stringWithFormat:@"Participant %@ disabled %@ audio track.",
                      participant.identity, publication.trackName]];
}

- (void)didFailToSubscribeToAudioTrack:(TVIRemoteAudioTrackPublication *)publication
                                 error:(NSError *)error
                        forParticipant:(TVIRemoteParticipant *)participant {
    [self logMessage:[NSString stringWithFormat:@"Participant %@ failed to subscribe to %@ audio track.",
                      participant.identity, publication.trackName]];
}

- (void)didFailToSubscribeToVideoTrack:(TVIRemoteVideoTrackPublication *)publication
                                 error:(NSError *)error
                        forParticipant:(TVIRemoteParticipant *)participant {
    [self logMessage:[NSString stringWithFormat:@"Participant %@ failed to subscribe to %@ video track.",
                      participant.identity, publication.trackName]];
}

#pragma mark - TVIVideoViewDelegate

- (void)videoView:(TVIVideoView *)view videoDimensionsDidChange:(CMVideoDimensions)dimensions {
    NSLog(@"Dimensions changed to: %d x %d", dimensions.width, dimensions.height);
    [self.view setNeedsLayout];
}

#pragma mark - TVICameraSourceDelegate

- (void)cameraSource:(TVICameraSource *)source didFailWithError:(NSError *)error {
    [self logMessage:[NSString stringWithFormat:@"Capture failed with error.\ncode = %lu error = %@", error.code, error.localizedDescription]];
}
/*
#pragma mark - TVIRoomDelegate

- (void)didConnectToRoom:(TVIRoom *)room {
    // At the moment, this example only supports rendering one Participant at a time.

    // [self logMessage:[NSString stringWithFormat:@"Connected to room %@ as %@", room.name, room.localParticipant.identity]];
    [self logMessage:@"Waiting on participant to join"];

    if (room.participants.count > 0) {
        self.participant = room.participants[0];
        self.participant.delegate = self;
        [self logMessage:@" "];
    }
}

- (void)room:(TVIRoom *)room didDisconnectWithError:(nullable NSError *)error {
    // [self logMessage:[NSString stringWithFormat:@"Disconncted from room %@, error = %@", room.name, error]];

    [self cleanupRemoteParticipant];
    self.room = nil;

    [self showRoomUI:NO];
}

- (void)room:(TVIRoom *)room didFailToConnectWithError:(nonnull NSError *)error{
    //  [self logMessage:[NSString stringWithFormat:@"Failed to connect to room, error = %@", error]];

    self.room = nil;

    [self showRoomUI:NO];
}

- (void)room:(TVIRoom *)room participantDidConnect:(TVIParticipant *)participant {
    if (!self.participant) {
        self.participant = participant;
        self.participant.delegate = self;
    }
    //   [self logMessage:[NSString stringWithFormat:@"Room %@ participant %@ connected", room.name, participant.identity]];
    [self logMessage:@" "];
}

- (void)room:(TVIRoom *)room participantDidDisconnect:(TVIParticipant *)participant {
    if (self.participant == participant) {
        [self cleanupRemoteParticipant];
    }
    // [self logMessage:[NSString stringWithFormat:@"Room %@ participant %@ disconnected", room.name, participant.identity]];
    [self logMessage:@"Participant disconnected"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

#pragma mark - TVIParticipantDelegate

- (void)participant:(TVIParticipant *)participant addedVideoTrack:(TVIVideoTrack *)videoTrack {
    //   [self logMessage:[NSString stringWithFormat:@"Participant %@ added video track.", participant.identity]];

    if (self.participant == participant) {
        [self setupRemoteView];
        [videoTrack addRenderer:self.remoteView];
    }
}

- (void)participant:(TVIParticipant *)participant removedVideoTrack:(TVIVideoTrack *)videoTrack {
    //   [self logMessage:[NSString stringWithFormat:@"Participant %@ removed video track.", participant.identity]];

    if (self.participant == participant) {
        [videoTrack removeRenderer:self.remoteView];
        [self.remoteView removeFromSuperview];
    }
}

- (void)participant:(TVIParticipant *)participant addedAudioTrack:(TVIAudioTrack *)audioTrack {
    //  [self logMessage:[NSString stringWithFormat:@"Participant %@ added audio track.", participant.identity]];
}

- (void)participant:(TVIParticipant *)participant removedAudioTrack:(TVIAudioTrack *)audioTrack {
    //  [self logMessage:[NSString stringWithFormat:@"Participant %@ removed audio track.", participant.identity]];
}

- (void)participant:(TVIParticipant *)participant enabledTrack:(TVITrack *)track {
    NSString *type = @"";
    if ([track isKindOfClass:[TVIAudioTrack class]]) {
        type = @"audio";
    } else {
        type = @"video";
    }
    //  [self logMessage:[NSString stringWithFormat:@"Participant %@ enabled %@ track.", participant.identity, type]];
}

- (void)participant:(TVIParticipant *)participant disabledTrack:(TVITrack *)track {
    NSString *type = @"";
    if ([track isKindOfClass:[TVIAudioTrack class]]) {
        type = @"audio";
    } else {
        type = @"video";
    }
    //  [self logMessage:[NSString stringWithFormat:@"Participant %@ disabled %@ track.", participant.identity, type]];
}

#pragma mark - TVIVideoViewDelegate

- (void)videoView:(TVIVideoView *)view videoDimensionsDidChange:(CMVideoDimensions)dimensions {
    NSLog(@"Dimensions changed to: %d x %d", dimensions.width, dimensions.height);
    [self.view setNeedsLayout];
}

#pragma mark - TVICameraCapturerDelegate

- (void)cameraCapturer:(TVICameraCapturer *)capturer didStartWithSource:(TVICameraCaptureSource)source {
    self.previewView.mirror = (source == TVICameraCaptureSourceFrontCamera);
}

#pragma mark - TVIVideoViewDelegate

- (void)videoView:(TVIVideoView *)view videoDimensionsDidChange:(CMVideoDimensions)dimensions {
    NSLog(@"Dimensions changed to: %d x %d", dimensions.width, dimensions.height);
    [self.view setNeedsLayout];
}

#pragma mark - TVICameraSourceDelegate

- (void)cameraSource:(TVICameraSource *)source didFailWithError:(NSError *)error {
    [self logMessage:[NSString stringWithFormat:@"Capture failed with error.\ncode = %lu error = %@", error.code, error.localizedDescription]];
}
*/
@end
