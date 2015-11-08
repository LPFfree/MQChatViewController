//
//  MQVoiceCellModel.m
//  MeiQiaSDK
//
//  Created by ijinmao on 15/10/29.
//  Copyright © 2015年 MeiQia Inc. All rights reserved.
//

#import "MQVoiceCellModel.h"
#import "MQChatBaseCell.h"
#import "MQVoiceMessageCell.h"
#import "MQChatViewConfig.h"
#import "MQStringSizeUtil.h"
#import "MQImageUtil.h"

/**
 * 语音播放图片与聊天气泡的间距
 */
static CGFloat const kMQCellVoiceImageToBubbleSpacing = 24.0;
/**
 * 语音时长label与气泡的间隔
 */
static CGFloat const kMQCellVoiceDurationLabelToBubbleSpacing = 8.0;


@interface MQVoiceCellModel()

/**
 * @brief cell中消息的id
 */
@property (nonatomic, readwrite, strong) NSString *messageId;

/**
 * @brief cell的宽度
 */
@property (nonatomic, readwrite, assign) CGFloat cellWidth;

/**
 * @brief cell的高度
 */
@property (nonatomic, readwrite, assign) CGFloat cellHeight;

/**
 * @brief 语音data
 */
@property (nonatomic, readwrite, copy) NSData *voiceData;

/**
 * @brief 语音的时长
 */
@property (nonatomic, readwrite, assign) NSInteger voiceDuration;

/**
 * @brief 消息的时间
 */
@property (nonatomic, readwrite, copy) NSDate *date;

/**
 * @brief 发送者的头像Path
 */
@property (nonatomic, readwrite, copy) NSString *avatarPath;

/**
 * @brief 发送者的头像的图片名字
 */
@property (nonatomic, readwrite, copy) UIImage *avatarImage;

/**
 * @brief 聊天气泡的image
 */
@property (nonatomic, readwrite, copy) UIImage *bubbleImage;

/**
 * @brief 消息气泡button的frame
 */
@property (nonatomic, readwrite, assign) CGRect bubbleImageFrame;

/**
 * @brief 发送者的头像frame
 */
@property (nonatomic, readwrite, assign) CGRect avatarFrame;

/**
 * @brief 发送状态指示器的frame
 */
@property (nonatomic, readwrite, assign) CGRect sendingIndicatorFrame;

/**
 * @brief 读取语音数据的指示器的frame
 */
@property (nonatomic, readwrite, assign) CGRect loadingIndicatorFrame;

/**
 * @brief 语音时长的frame
 */
@property (nonatomic, readwrite, assign) CGRect durationLabelFrame;

/**
 * @brief 语音图片的frame
 */
@property (nonatomic, readwrite, assign) CGRect voiceImageFrame;

/**
 * @brief 发送出错图片的frame
 */
@property (nonatomic, readwrite, assign) CGRect sendFailureFrame;

/**
 * @brief 消息的来源类型
 */
@property (nonatomic, readwrite, assign) MQChatCellFromType cellFromType;

@end

@implementation MQVoiceCellModel

#pragma initialize
/**
 *  根据MQMessage内容来生成cell model
 */
- (MQVoiceCellModel *)initCellModelWithMessage:(MQVoiceMessage *)message
                                     cellWidth:(CGFloat)cellWidth
                                      delegate:(id<MQCellModelDelegate>)delegator{
    if (self = [super init]) {
        self.delegate = delegator;
        self.messageId = message.messageId;
        self.sendStatus = message.sendStatus;
        self.date = message.date;
        self.avatarPath = @"";
        if (message.userAvatarImage) {
            self.avatarImage = message.userAvatarImage;
        } else if (message.userAvatarPath.length > 0) {
            self.avatarPath = message.userAvatarPath;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:message.userAvatarPath]];
                self.avatarImage = [UIImage imageWithData:imageData];
            });
        } else {
            self.avatarImage = [MQChatViewConfig sharedConfig].agentDefaultAvatarImage;
        }
        self.voiceDuration = 0;
        
        //获取语音数据
        self.voiceData = message.voiceData;
        if (!self.voiceData) {
            if (message.voicePath.length > 0) {
                //新建线程读取远程图片
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSData *voiceData = [NSData dataWithContentsOfURL:[NSURL URLWithString:message.voicePath]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (voiceData) {
                            self.voiceData = voiceData;
                            self.voiceDuration = [MQChatFileUtil getAudioDurationWithData:voiceData];
                            if (self.delegate) {
                                if ([self.delegate respondsToSelector:@selector(didUpdateCellDataWithMessageId:)]) {
                                    [self.delegate didUpdateCellDataWithMessageId:self.messageId];
                                }
                            }
                        }
                        [self setModelsWithMessage:message cellWidth:cellWidth];
                    });
                });
            }
        } else {
            self.voiceDuration = [MQChatFileUtil getAudioDurationWithData:self.voiceData];
        }
        [self setModelsWithMessage:message cellWidth:cellWidth];
    }
    return self;
}

//根据气泡中的图片生成其他model
- (void)setModelsWithMessage:(MQVoiceMessage *)message
                   cellWidth:(CGFloat)cellWidth
{
    //由于语音可能是小数，故+1
    self.voiceDuration++ ;
    //语音图片size
    UIImage *voiceImage = [UIImage imageNamed:[MQChatFileUtil resourceWithName:@"MQBubble_voice_animation_gray3"]];
    CGSize voiceImageSize = voiceImage.size;

    //气泡高度
    CGFloat bubbleHeight = kMQCellAvatarDiameter;
    
    //根据语音时长来确定气泡宽度
    CGFloat maxBubbleWidth = cellWidth - kMQCellAvatarToHorizontalEdgeSpacing - kMQCellAvatarDiameter - kMQCellAvatarToBubbleSpacing - kMQCellBubbleMaxWidthToEdgeSpacing;
    CGFloat bubbleWidth = maxBubbleWidth;
    if (self.voiceDuration < [MQChatViewConfig sharedConfig].maxVoiceDuration) {
        CGFloat upWidth = floor(cellWidth / 4);   //根据语音时间来递增的基准
        CGFloat voiceWidthScale = self.voiceDuration / [MQChatViewConfig sharedConfig].maxVoiceDuration;
        bubbleWidth = floor(upWidth*voiceWidthScale) + floor(cellWidth/4);
    } else {
        NSAssert(NO, @"语音超过最大时长！");
    }
    
    //语音时长label的宽高
    CGFloat durationTextHeight = [MQStringSizeUtil getHeightForText:[NSString stringWithFormat:@"%d\"", (int)self.voiceDuration] withFont:[UIFont systemFontOfSize:kMQCellVoiceDurationLabelFontSize] andWidth:cellWidth];
    CGFloat durationTextWidth = [MQStringSizeUtil getWidthForText:[NSString stringWithFormat:@"%d\"", (int)self.voiceDuration] withFont:[UIFont systemFontOfSize:kMQCellVoiceDurationLabelFontSize] andHeight:durationTextHeight];
    
    //根据消息的来源，进行处理
    UIImage *bubbleImage = [MQChatViewConfig sharedConfig].incomingBubbleImage;
    if ([MQChatViewConfig sharedConfig].incomingBubbleColor) {
        bubbleImage = [MQImageUtil convertImageColorWithImage:bubbleImage toColor:[MQChatViewConfig sharedConfig].incomingBubbleColor];
    }
    if (message.fromType == MQChatMessageOutgoing) {
        //发送出去的消息
        self.cellFromType = MQChatCellOutgoing;
        bubbleImage = [MQChatViewConfig sharedConfig].outgoingBubbleImage;
        if ([MQChatViewConfig sharedConfig].outgoingBubbleColor) {
            bubbleImage = [MQImageUtil convertImageColorWithImage:bubbleImage toColor:[MQChatViewConfig sharedConfig].outgoingBubbleColor];
        }
        //头像的frame
        if ([MQChatViewConfig sharedConfig].enableClientAvatar) {
            self.avatarFrame = CGRectMake(cellWidth-kMQCellAvatarToHorizontalEdgeSpacing-kMQCellAvatarDiameter, kMQCellAvatarToVerticalEdgeSpacing, kMQCellAvatarDiameter, kMQCellAvatarDiameter);
        } else {
            self.avatarFrame = CGRectMake(0, 0, 0, 0);
        }
        //气泡的frame
        self.bubbleImageFrame = CGRectMake(cellWidth-kMQCellAvatarToBubbleSpacing-bubbleWidth, kMQCellAvatarToVerticalEdgeSpacing, bubbleWidth, bubbleHeight);
        //语音图片的frame
        self.voiceImageFrame = CGRectMake(self.bubbleImageFrame.size.width-kMQCellVoiceImageToBubbleSpacing-voiceImageSize.width, self.bubbleImageFrame.size.height/2-voiceImageSize.height/2, voiceImageSize.width, voiceImageSize.height);
        //语音时长的frame
        self.durationLabelFrame = CGRectMake(self.bubbleImageFrame.origin.x-kMQCellVoiceDurationLabelToBubbleSpacing-durationTextWidth, self.bubbleImageFrame.origin.y+self.bubbleImageFrame.size.height/2-durationTextHeight/2, durationTextWidth, durationTextHeight);
    } else {
        //收到的消息
        self.cellFromType = MQChatCellIncoming;
        //头像的frame
        if ([MQChatViewConfig sharedConfig].enableClientAvatar) {
            self.avatarFrame = CGRectMake(kMQCellAvatarToHorizontalEdgeSpacing, kMQCellAvatarToVerticalEdgeSpacing, kMQCellAvatarDiameter, kMQCellAvatarDiameter);
        } else {
            self.avatarFrame = CGRectMake(0, 0, 0, 0);
        }
        //气泡的frame
        self.bubbleImageFrame = CGRectMake(self.avatarFrame.origin.x+self.avatarFrame.size.width+kMQCellAvatarToBubbleSpacing, self.avatarFrame.origin.y, bubbleWidth, bubbleHeight);
        //语音图片的frame
        self.voiceImageFrame = CGRectMake(kMQCellVoiceImageToBubbleSpacing, self.bubbleImageFrame.size.height/2-voiceImageSize.height/2, voiceImageSize.width, voiceImageSize.height);
        //语音时长的frame
        self.durationLabelFrame = CGRectMake(self.bubbleImageFrame.origin.x+self.bubbleImageFrame.size.width+kMQCellVoiceDurationLabelToBubbleSpacing, self.bubbleImageFrame.origin.y+self.bubbleImageFrame.size.height/2-durationTextHeight/2, durationTextWidth, durationTextHeight);
    }
    
    
    //loading image的indicator
    self.loadingIndicatorFrame = CGRectMake(self.bubbleImageFrame.size.width/2-kMQCellIndicatorDiameter/2, self.bubbleImageFrame.size.height/2-kMQCellIndicatorDiameter/2, kMQCellIndicatorDiameter, kMQCellIndicatorDiameter);
    
    //气泡图片
    CGPoint centerArea = CGPointMake(bubbleImage.size.width / 4.0f, bubbleImage.size.height*3.0f / 4.0f);
    self.bubbleImage = [bubbleImage resizableImageWithCapInsets:UIEdgeInsetsMake(centerArea.y, centerArea.x, bubbleImage.size.height-centerArea.y+1, centerArea.x)];
    
    //发送消息的indicator的frame
    UIActivityIndicatorView *indicatorView = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, kMQCellIndicatorDiameter, kMQCellIndicatorDiameter)];
    self.sendingIndicatorFrame = CGRectMake(self.bubbleImageFrame.origin.x-kMQCellBubbleToIndicatorSpacing-indicatorView.frame.size.width, self.bubbleImageFrame.origin.y+self.bubbleImageFrame.size.height/2-indicatorView.frame.size.height/2, indicatorView.frame.size.width, indicatorView.frame.size.height);
    
    //发送失败的图片frame
    UIImage *failureImage = [UIImage imageNamed:[MQChatFileUtil resourceWithName:@"MQMessageWarning"]];
    CGSize failureSize = CGSizeMake(ceil(failureImage.size.width * 2 / 3), ceil(failureImage.size.height * 2 / 3));
    self.sendFailureFrame = CGRectMake(self.bubbleImageFrame.origin.x-kMQCellBubbleToIndicatorSpacing-failureSize.width, self.bubbleImageFrame.origin.y+self.bubbleImageFrame.size.height/2-failureSize.height/2, failureSize.width, failureSize.height);
    
    //计算cell的高度
    self.cellHeight = self.bubbleImageFrame.origin.y + self.bubbleImageFrame.size.height + kMQCellAvatarToVerticalEdgeSpacing;
    
}

#pragma MQCellModelProtocol
- (CGFloat)getCellHeight {
    return self.cellHeight;
}

/**
 *  通过重用的名字初始化cell
 *  @return 初始化了一个cell
 */
- (MQChatBaseCell *)getCellWithReuseIdentifier:(NSString *)cellReuseIdentifer {
    return [[MQVoiceMessageCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellReuseIdentifer];
}

- (NSDate *)getCellDate {
    return self.date;
}

- (BOOL)isServiceRelatedCell {
    return true;
}

- (NSString *)getCellMessageId {
    return self.messageId;
}

- (void)updateCellSendStatus:(MQChatMessageSendStatus)sendStatus {
    self.sendStatus = sendStatus;
}

- (void)updateCellMessageId:(NSString *)messageId {
    self.messageId = messageId;
}

- (void)updateCellMessageDate:(NSDate *)messageDate {
    self.date = messageDate;
}

- (void)updateCellFrameWithCellWidth:(CGFloat)cellWidth {
    self.cellWidth = cellWidth;
    if (self.cellFromType == MQChatCellOutgoing) {
        //头像的frame
        if ([MQChatViewConfig sharedConfig].enableClientAvatar) {
            self.avatarFrame = CGRectMake(cellWidth-kMQCellAvatarToHorizontalEdgeSpacing-kMQCellAvatarDiameter, kMQCellAvatarToVerticalEdgeSpacing, kMQCellAvatarDiameter, kMQCellAvatarDiameter);
        } else {
            self.avatarFrame = CGRectMake(0, 0, 0, 0);
        }
        //气泡的frame
        self.bubbleImageFrame = CGRectMake(cellWidth-self.avatarFrame.origin.x-kMQCellAvatarToBubbleSpacing-self.bubbleImageFrame.size.width, kMQCellAvatarToVerticalEdgeSpacing, self.bubbleImageFrame.size.width, self.bubbleImageFrame.size.height);
        //发送指示器的frame
        self.sendingIndicatorFrame = CGRectMake(self.bubbleImageFrame.origin.x-kMQCellBubbleToIndicatorSpacing-self.sendingIndicatorFrame.size.width, self.sendingIndicatorFrame.origin.y, self.sendingIndicatorFrame.size.width, self.sendingIndicatorFrame.size.height);
        //发送出错图片的frame
        self.sendFailureFrame = CGRectMake(self.bubbleImageFrame.origin.x-kMQCellBubbleToIndicatorSpacing-self.sendFailureFrame.size.width, self.sendFailureFrame.origin.y, self.sendFailureFrame.size.width, self.sendFailureFrame.size.height);
        //语音时长的frame
        self.durationLabelFrame = CGRectMake(self.bubbleImageFrame.origin.x-kMQCellBubbleToIndicatorSpacing-self.durationLabelFrame.size.width, self.durationLabelFrame.origin.y, self.durationLabelFrame.size.width, self.durationLabelFrame.size.height);
    }
}


@end
