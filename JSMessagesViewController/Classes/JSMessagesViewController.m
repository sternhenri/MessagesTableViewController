//
//  Created by Jesse Squires on 2/12/13.
//  Copyright (c) 2013 Hexed Bits. All rights reserved.
//
//  http://www.hexedbits.com
//
//
//  Originally based on work by Sam Soffes
//  https://github.com/soffes
//
//  SSMessagesViewController
//  https://github.com/soffes/ssmessagesviewcontroller
//
//
//  The MIT License
//  Copyright (c) 2013 Jesse Squires
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
//  associated documentation files (the "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
//  following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
//  LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
//  OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "JSMessagesViewController.h"
#import "JSMessageTextView.h"

#import "NSString+JSMessagesView.h"
#import "UIView+AnimationOptionsForCurve.h"
#import "UIColor+JSMessagesView.h"
#import "UIButton+JSMessagesView.h"

#define INPUT_HEIGHT 40.0f

@interface JSMessagesViewController () <JSDismissiveTextViewDelegate>

@property (strong, nonatomic) UITableView *tableView;
@property (strong, nonatomic) JSMessageInputView *inputToolbarView;
@property (assign, nonatomic) CGFloat previousTextViewContentHeight;

@property (assign, nonatomic) BOOL isUserScrolling;

- (void)setup;

- (void)sendPressed:(UIButton *)sender;

- (BOOL)shouldAllowScroll;

- (void)handleWillShowKeyboardNotification:(NSNotification *)notification;
- (void)handleWillHideKeyboardNotification:(NSNotification *)notification;
- (void)keyboardWillShowHide:(NSNotification *)notification;

@end



@implementation JSMessagesViewController

#pragma mark - Initialization

- (void)setup
{
    if([self.view isKindOfClass:[UIScrollView class]]) {
        // fix for ipad modal form presentations
        ((UIScrollView *)self.view).scrollEnabled = NO;
    }
    
	_isUserScrolling = NO;
    
    CGSize size = self.view.frame.size;
	
    CGRect tableFrame = CGRectMake(0.0f, 0.0f, size.width, size.height - INPUT_HEIGHT);
	_tableView = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_tableView.dataSource = self;
	_tableView.delegate = self;
	[self.view addSubview:_tableView];
	
    [self setBackgroundColor:[UIColor js_messagesBackgroundColor_iOS6]];
    
    CGRect inputFrame = CGRectMake(0.0f, size.height - INPUT_HEIGHT, size.width, INPUT_HEIGHT);
    _inputToolbarView = [[JSMessageInputView alloc] initWithFrame:inputFrame
                                                 textViewDelegate:self
                                                 keyboardDelegate:self
                                             panGestureRecognizer:_tableView.panGestureRecognizer];
    
    UIButton *sendButton;
    if([self.delegate respondsToSelector:@selector(sendButtonForInputView)]) {
        sendButton = [self.delegate sendButtonForInputView];
    }
    else {
        sendButton = [UIButton js_defaultSendButton_iOS6];
    }
    sendButton.enabled = NO;
    sendButton.frame = CGRectMake(_inputToolbarView.frame.size.width - 65.0f, 8.0f, 59.0f, 26.0f);
    [sendButton addTarget:self
                   action:@selector(sendPressed:)
         forControlEvents:UIControlEventTouchUpInside];
    [_inputToolbarView setSendButton:sendButton];
    [self.view addSubview:_inputToolbarView];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setup];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self scrollToBottomAnimated:NO];
    
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleWillShowKeyboardNotification:)
												 name:UIKeyboardWillShowNotification
                                               object:nil];
    
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleWillHideKeyboardNotification:)
												 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self.inputToolbarView resignFirstResponder];
    [self setEditing:NO animated:YES];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    NSLog(@"*** %@: didReceiveMemoryWarning ***", self.class);
}

- (void)dealloc
{
    _delegate = nil;
    _dataSource = nil;
    _tableView = nil;
    _inputToolbarView = nil;
}

#pragma mark - View rotation

- (BOOL)shouldAutorotate
{
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self.tableView reloadData];
    [self.tableView setNeedsLayout];
}

#pragma mark - Actions

- (void)sendPressed:(UIButton *)sender
{
    [self.delegate didSendText:[self.inputToolbarView.textView.text js_stringByTrimingWhitespace]];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    JSBubbleMessageType type = [self.delegate messageTypeForRowAtIndexPath:indexPath];
    
    UIImageView *bubbleImageView = [self.delegate bubbleImageViewWithType:type
                                                        forRowAtIndexPath:indexPath];
    
    BOOL hasTimestamp = [self shouldHaveTimestampForRowAtIndexPath:indexPath];
    BOOL hasAvatar = [self shouldHaveAvatarForRowAtIndexPath:indexPath];
	BOOL hasSubtitle = [self shouldHaveSubtitleForRowAtIndexPath:indexPath];
    
    NSString *CellIdentifier = [NSString stringWithFormat:@"MessageCell_%d_%d_%d_%d", type, hasTimestamp, hasAvatar, hasSubtitle];
    JSBubbleMessageCell *cell = (JSBubbleMessageCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if(!cell) {
        cell = [[JSBubbleMessageCell alloc] initWithBubbleType:type
                                               bubbleImageView:bubbleImageView
                                                  hasTimestamp:hasTimestamp
                                                     hasAvatar:hasAvatar
                                                   hasSubtitle:hasSubtitle
                                               reuseIdentifier:CellIdentifier];
    }
    
    if(hasTimestamp) {
        [cell setTimestamp:[self.dataSource timestampForRowAtIndexPath:indexPath]];
    }
	
    if(hasAvatar) {
        [cell setAvatarImageView:[self.dataSource avatarImageViewForRowAtIndexPath:indexPath]];
    }
    
	if(hasSubtitle) {
		[cell setSubtitle:[self.dataSource subtitleForRowAtIndexPath:indexPath]];
    }
    
    [cell setMessage:[self.dataSource textForRowAtIndexPath:indexPath]];
    [cell setBackgroundColor:tableView.backgroundColor];
    return cell;
}

#pragma mark - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [(JSBubbleMessageCell *)[self tableView:tableView cellForRowAtIndexPath:indexPath] height];
}

#pragma mark - Messages view controller

- (BOOL)shouldHaveTimestampForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch ([self.delegate timestampPolicy]) {
        case JSMessagesViewTimestampPolicyAll:
            return YES;
            
        case JSMessagesViewTimestampPolicyAlternating:
            return indexPath.row % 2 == 0;
            
        case JSMessagesViewTimestampPolicyEveryThree:
            return indexPath.row % 3 == 0;
            
        case JSMessagesViewTimestampPolicyEveryFive:
            return indexPath.row % 5 == 0;
            
        case JSMessagesViewTimestampPolicyCustom:
            if([self.delegate respondsToSelector:@selector(hasTimestampForRowAtIndexPath:)])
                return [self.delegate hasTimestampForRowAtIndexPath:indexPath];
            
        default:
            return NO;
    }
}

- (BOOL)shouldHaveAvatarForRowAtIndexPath:(NSIndexPath *)indexPath
{
	switch ([self.delegate avatarPolicy]) {
        case JSMessagesViewAvatarPolicyAll:
            return YES;
            
        case JSMessagesViewAvatarPolicyIncomingOnly:
            return [self.delegate messageTypeForRowAtIndexPath:indexPath] == JSBubbleMessageTypeIncoming;
			
		case JSMessagesViewAvatarPolicyOutgoingOnly:
			return [self.delegate messageTypeForRowAtIndexPath:indexPath] == JSBubbleMessageTypeOutgoing;
            
        case JSMessagesViewAvatarPolicyNone:
        default:
            return NO;
    }
}

- (BOOL)shouldHaveSubtitleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch ([self.delegate subtitlePolicy]) {
        case JSMessagesViewSubtitlePolicyAll:
            return YES;
        
        case JSMessagesViewSubtitlePolicyIncomingOnly:
            return [self.delegate messageTypeForRowAtIndexPath:indexPath] == JSBubbleMessageTypeIncoming;
            
        case JSMessagesViewSubtitlePolicyOutgoingOnly:
            return [self.delegate messageTypeForRowAtIndexPath:indexPath] == JSBubbleMessageTypeOutgoing;
            
        case JSMessagesViewSubtitlePolicyNone:
        default:
            return NO;
    }
}

- (void)finishSend
{
    [self.inputToolbarView.textView setText:nil];
    [self textViewDidChange:self.inputToolbarView.textView];
    [self.tableView reloadData];
}

- (void)setBackgroundColor:(UIColor *)color
{
    self.view.backgroundColor = color;
    _tableView.backgroundColor = color;
    _tableView.separatorColor = color;
}

- (void)scrollToBottomAnimated:(BOOL)animated
{
	if(![self shouldAllowScroll])
        return;
	
    NSInteger rows = [self.tableView numberOfRowsInSection:0];
    
    if(rows > 0) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:rows - 1 inSection:0]
                              atScrollPosition:UITableViewScrollPositionBottom
                                      animated:animated];
    }
}

- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath
			  atScrollPosition:(UITableViewScrollPosition)position
					  animated:(BOOL)animated
{
	if(![self shouldAllowScroll])
        return;
	
	[self.tableView scrollToRowAtIndexPath:indexPath
						  atScrollPosition:position
								  animated:animated];
}

- (BOOL)shouldAllowScroll
{
    if(self.isUserScrolling) {
        if([self.delegate respondsToSelector:@selector(shouldPreventScrollToBottomWhileUserScrolling)]
           && [self.delegate shouldPreventScrollToBottomWhileUserScrolling]) {
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - Scroll view delegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
	self.isUserScrolling = YES;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    self.isUserScrolling = NO;
}

#pragma mark - Text view delegate

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    [textView becomeFirstResponder];
	
    if(!self.previousTextViewContentHeight)
		self.previousTextViewContentHeight = textView.contentSize.height;
    
    [self scrollToBottomAnimated:YES];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    [textView resignFirstResponder];
}

- (void)textViewDidChange:(UITextView *)textView
{
    CGFloat maxHeight = [JSMessageInputView maxHeight];
    
    //  TODO:
    //
    //  CGFloat textViewContentHeight = textView.contentSize.height;
    //
    //  The line above is broken as of iOS 7.0
    //
    //  There seems to be a bug in Apple's code for textView.contentSize
    //  The following code was implemented as a workaround for calculating the appropriate textViewContentHeight
    //
    //  https://devforums.apple.com/thread/192052
    //  https://github.com/jessesquires/MessagesTableViewController/issues/50
    //  https://github.com/jessesquires/MessagesTableViewController/issues/47
    //
    // BEGIN HACK
    //
        CGSize size = [textView sizeThatFits:CGSizeMake(textView.frame.size.width, maxHeight)];
        CGFloat textViewContentHeight = size.height;
    //
    //  END HACK
    //
    
    BOOL isShrinking = textViewContentHeight < self.previousTextViewContentHeight;
    CGFloat changeInHeight = textViewContentHeight - self.previousTextViewContentHeight;
    
    if(!isShrinking && self.previousTextViewContentHeight == maxHeight) {
        changeInHeight = 0;
    }
    else {
        changeInHeight = MIN(changeInHeight, maxHeight - self.previousTextViewContentHeight);
    }
    
    if(changeInHeight != 0.0f) {
        if(!isShrinking)
            [self.inputToolbarView adjustTextViewHeightBy:changeInHeight];
        
        [UIView animateWithDuration:0.25f
                         animations:^{
                             UIEdgeInsets insets = UIEdgeInsetsMake(0.0f,
                                                                    0.0f,
                                                                    self.tableView.contentInset.bottom + changeInHeight,
                                                                    0.0f);
                             
                             self.tableView.contentInset = insets;
                             self.tableView.scrollIndicatorInsets = insets;
                             [self scrollToBottomAnimated:NO];
                             
                             CGRect inputViewFrame = self.inputToolbarView.frame;
                             self.inputToolbarView.frame = CGRectMake(0.0f,
                                                                      inputViewFrame.origin.y - changeInHeight,
                                                                      inputViewFrame.size.width,
                                                                      inputViewFrame.size.height + changeInHeight);
                         }
                         completion:^(BOOL finished) {
                             if(isShrinking)
                                 [self.inputToolbarView adjustTextViewHeightBy:changeInHeight];
                         }];
        
        self.previousTextViewContentHeight = MIN(textViewContentHeight, maxHeight);
    }
    
    self.inputToolbarView.sendButton.enabled = ([textView.text js_stringByTrimingWhitespace].length > 0);
}

#pragma mark - Keyboard notifications

- (void)handleWillShowKeyboardNotification:(NSNotification *)notification
{
    [self keyboardWillShowHide:notification];
}

- (void)handleWillHideKeyboardNotification:(NSNotification *)notification
{
    [self keyboardWillShowHide:notification];
}

- (void)keyboardWillShowHide:(NSNotification *)notification
{
    CGRect keyboardRect = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	UIViewAnimationCurve curve = [[notification.userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
	double duration = [[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    [UIView animateWithDuration:duration
                          delay:0.0f
                        options:[UIView js_animationOptionsForCurve:curve]
                     animations:^{
                         CGFloat keyboardY = [self.view convertRect:keyboardRect fromView:nil].origin.y;
                         
                         CGRect inputViewFrame = self.inputToolbarView.frame;
                         CGFloat inputViewFrameY = keyboardY - inputViewFrame.size.height;
                         
                         // for ipad modal form presentations
                         CGFloat messageViewFrameBottom = self.view.frame.size.height - INPUT_HEIGHT;
                         if(inputViewFrameY > messageViewFrameBottom)
                             inputViewFrameY = messageViewFrameBottom;
						 
                         self.inputToolbarView.frame = CGRectMake(inputViewFrame.origin.x,
																  inputViewFrameY,
																  inputViewFrame.size.width,
																  inputViewFrame.size.height);
                         
                         UIEdgeInsets insets = UIEdgeInsetsMake(0.0f,
                                                                0.0f,
                                                                self.view.frame.size.height - self.inputToolbarView.frame.origin.y - INPUT_HEIGHT,
                                                                0.0f);
                         
                         self.tableView.contentInset = insets;
                         self.tableView.scrollIndicatorInsets = insets;
                     }
                     completion:^(BOOL finished) {
                     }];
}

#pragma mark - Dismissive text view delegate

- (void)keyboardDidScrollToPoint:(CGPoint)point
{
    CGRect inputViewFrame = self.inputToolbarView.frame;
    CGPoint keyboardOrigin = [self.view convertPoint:point fromView:nil];
    inputViewFrame.origin.y = keyboardOrigin.y - inputViewFrame.size.height;
    self.inputToolbarView.frame = inputViewFrame;
}

- (void)keyboardWillBeDismissed
{
    CGRect inputViewFrame = self.inputToolbarView.frame;
    inputViewFrame.origin.y = self.view.bounds.size.height - inputViewFrame.size.height;
    self.inputToolbarView.frame = inputViewFrame;
}

- (void)keyboardWillSnapBackToPoint:(CGPoint)point
{
    CGRect inputViewFrame = self.inputToolbarView.frame;
    CGPoint keyboardOrigin = [self.view convertPoint:point fromView:nil];
    inputViewFrame.origin.y = keyboardOrigin.y - inputViewFrame.size.height;
    self.inputToolbarView.frame = inputViewFrame;
}

@end