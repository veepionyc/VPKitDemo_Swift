//
//  ViewController.m
//  VPKitDemo
//
//  Created by jonathan on 01/03/2016.
//  Copyright © 2016 jonathan. All rights reserved.
//

#import "ViewController.h"
#import "ViewController_AutoLayout.h"
#import <VPKit/VPKit.h>

@import AVFoundation;
@import AVKit;

#define LOG_ME 1

@interface ViewController ()
<
  VPKVeepViewerDelegate
, VPKVeepEditorDelegate
, VPKPreviewDelegate
>

//@property (nonatomic, strong) VPKVeepViewer* vpViewer;
//@property (nonatomic, strong) VPKVeepEditor* vpEditor;


@end

@implementation ViewController




#pragma mark - viewController lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.versionLabel.text = [VPKit sdkVersion];
    [self configureViewerWithTestVideo];
    [self configureEditor];
    self.constraints = [[NSMutableArray alloc] init];
    [self configureConstraints];
    [self configureErrorHandling];

}


- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - error handling

/*
 error handling is optional
 */

- (void)configureErrorHandling {
    
    [VPKit forwardErrorNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(errorNotification:) name:vpkErrorNotification object:nil];
}

- (void)errorNotification:(NSNotification*)notification {
    NSError* error = notification.userInfo[vpkErrorKey];
    
    /*
     shouldAlertUser is advisory - that the error is of a type the user should be alerted to.
     */
    BOOL shouldAlertUser = [notification.userInfo[vpkPresentErrorKey] boolValue];

    NSLog(@"%s %@",__func__,error);
    if (shouldAlertUser) {
        //present error dialog
    }
}



#pragma mark - configuration



- (void)configureViewerWithTestImage {
    UIImage* image = [UIImage imageNamed:@"KrispyGlas"];
    image = [[VPKImage alloc] initWithImage:image veepId:@"1787"];
    self.viewerPreview.image = image;
    self.viewerPreview.delegate = self;

}

- (void)configureViewerWithTestVideo {
    UIImage* image = [UIImage imageNamed:@"tomcruise"];
    image = [[VPKImage alloc] initWithImage:image veepId:@"1788"];
    self.viewerPreview.image = image;
    self.viewerPreview.delegate = self;

    
}


- (void)configureEditor {
    UIImage* image = [UIImage imageNamed:@"stock_photo"];
    image = [[VPKImage alloc] initWithImage:image veepId:nil];
    self.editorPreview.image = image;
    /*
     for the editor example, we'll set an optional delegate.
     */
    self.editorPreview.delegate = self;
}




#pragma mark - VPKPreview delegate


- (void)vpkPreviewTouched:(VPKPreview *)preview image:(VPKImage*)image {
    [preview hideIcon];

    if ([preview isEqual:self.viewerPreview]) {
        [self invokeViewer:image fromView:preview];
    } else {
        [self invokeEditor:image fromView:preview];
    }
}

- (void)invokeViewer:(VPKImage*)image fromView:(UIView*)view {
    
    /*
     invoking the VPKVeepViewer
     
     set the viewer's transitioning delegate to a custom transitioning object (or nil) to override supplied transition animations
     
     this code is all OPTIONAL - if you don't set the delegate on VPKPreview, presenting and dismissing behaviour occurs as a default
     
     */
    
    
    VPKVeepViewer* vpViewer =  [VPKit viewerWithImage:image
                                   fromView:view];
    [VPKit presentViewer:vpViewer];

}

- (void)invokeEditor:(VPKImage*)image fromView:(UIView*)view {
    
    /*
        
     invoking the VPKVeepEditor
     
     set the editor's transitioning delegate to a custom transitioning object (or nil) to override supplied transition animations
     
     this code is all OPTIONAL - if you don't set the delegate on VPKPreview, presenting and dismissing behaviour occurs as a default. However, at some point before invoking the editor, user authentication needs to be dealt with.

    */
    
    UIActivityIndicatorView* activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    activityView.center = CGPointMake(self.editorPreview.bounds.size.width/2.0f, self.editorPreview.bounds.size.height/2.0f);
    [self.editorPreview addSubview:activityView];
    [activityView startAnimating];
    
    /*
     
     Authentication
     
     We authenticate before invoking the editor, as veep creation requires an authenticated user.
     
     Authenticated users are weak (no password) or strong (password-protected)
     
     If responseCode to a weak login attempt is 401 (unauthorised), we can make a similar call for strong authentication with a password.
     
     User account admin can be an implementation detail in the host app or the Veepio Developer control panel.
     
     */
    
    [VPKit authenticateWithEmail:@"test@example.com"
                      completion:^(BOOL success, NSInteger responseCode, NSError * _Nonnull error) {

       [activityView removeFromSuperview];
        
        if (success) {
            error = nil;
            VPKVeepEditor* vpEditor =  [VPKit editorWithImage:image
                                                 fromView:view error:&error];
            if (vpEditor) {
                vpEditor.delegate = self;
                vpEditor.modalPresentationStyle = UIModalPresentationOverFullScreen;
                [self presentViewController:vpEditor animated:YES completion:nil];
            } else {
                NSLog(@"%@",error);
            }
        } else {
            NSLog(@"%@",error);
        }
    }];
    

}


#pragma mark - VPKViewController delegate

/*
    example delegate methods for VPKVeepViewer
 
 */

- (void)veepViewer:(VPKVeepViewer *)viewer didFinishViewingWithInfo:(NSDictionary *)info {
    VPKPublicVeep* pVeep = info[@"veep"];
    NSLog(@"%s %@",__func__, pVeep);
    __weak typeof(self) weakself = self;
    [self dismissViewControllerAnimated:YES completion:^{
        [weakself.viewerPreview showIcon];
    }];
}

- (void)veepViewerDidCancel:(VPKVeepViewer *)viewer {
    NSLog(@"%s",__func__);
    [self dismissViewControllerAnimated:YES completion:nil];
}

/*
    example delegate mathods for VPKVeepEditor
 
 */

- (void)veepEditor:(VPKVeepEditor *)editor didPublishVeep:(NSString *)veepId  {
   
    NSLog(@"%s %@",__func__,veepId);
    [self dismissViewControllerAnimated:YES completion:^{
        //test that we can fetch the veep we just published
        [VPKit requestVeep:veepId completionBlock:
         ^(VPKPublicVeep * _Nullable veep, NSError * _Nullable error) {
             NSLog(@"%@",veep);
         }];
    }];
}

- (void)veepEditorDidCancel:(VPKVeepEditor *)editor {
    NSLog(@"%s",__func__);
    [self dismissViewControllerAnimated:YES completion:nil];

}



@end
