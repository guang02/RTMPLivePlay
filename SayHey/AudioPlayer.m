//
//  AudioPlayer.m
//  SayHey
//
//  Created by Mingliang Chen on 13-12-12.
//  Copyright (c) 2013年 Mingliang Chen. All rights reserved.
//

#import "AudioPlayer.h"

@implementation AudioPlayer


void AQBufferCallback(void *inUserData,
                      AudioQueueRef			inAQ,
                      AudioQueueBufferRef	inCompleteAQBuffer)
{
    AudioPlayer *THIS = (__bridge AudioPlayer *)(inUserData);
    
    if(THIS->isStartPlay)
    {
        inCompleteAQBuffer->mPacketDescriptionCount = THIS->mBufferByteSize/2;
        inCompleteAQBuffer->mAudioDataByteSize =THIS->mBufferByteSize;
        if(read(THIS->pip_fd[0], inCompleteAQBuffer->mAudioData, THIS->mBufferByteSize) > 0 ){
            AudioQueueEnqueueBuffer(inAQ, inCompleteAQBuffer, 0, NULL);
        }
    }
    
}

-(id)initWithSampleRate:(int)sampleRate
{
    self = [super init];
    if(self)
    {
        memset(&mPlayFormat, 0, sizeof(mPlayFormat));
        mPlayFormat.mFormatID = kAudioFormatLinearPCM;
        mPlayFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsNonInterleaved;

        mPlayFormat.mBitsPerChannel = 16;
        mPlayFormat.mChannelsPerFrame = 2;
        mPlayFormat.mBytesPerPacket = mPlayFormat.mBytesPerFrame = (mPlayFormat.mBitsPerChannel / 8) * mPlayFormat.mChannelsPerFrame;
        mPlayFormat.mFramesPerPacket = 2;
        mPlayFormat.mSampleRate = sampleRate;
        
        isStartPlay = NO;
    }
    return self;
}

-(void)startPlayWithBufferByteSize:(int)bufferByteSize
{
    mBufferByteSize = bufferByteSize;
    OSStatus status  = AudioQueueNewOutput(&mPlayFormat, AQBufferCallback, (__bridge void *)(self), CFRunLoopGetMain(), kCFRunLoopDefaultMode, 0, &mQueue);
    
    for (int i=0; i<kNumberBuffers; i++) {
        status =  AudioQueueAllocateBufferWithPacketDescriptions(mQueue, mBufferByteSize, 0, &mBuffers[i]);
    }
    pipe(pip_fd);
}

-(void)stopPlay
{
    close(pip_fd[0]);
    close(pip_fd[1]);
    AudioQueueStop(mQueue, true);
    if (mQueue)
	{
		AudioQueueDispose(mQueue, true);
		mQueue = NULL;
        isStartPlay = NO;
	}
    NSLog(@"stop play queue");
}

-(void)putAudioData:(short*)pcmData
{
    if (!isStartPlay) {
        memcpy(mBuffers[mIndex]->mAudioData, pcmData, mBufferByteSize);
        mBuffers[mIndex]->mAudioDataByteSize = mBufferByteSize;
        mBuffers[mIndex]->mPacketDescriptionCount = mBufferByteSize/2;
        OSStatus status = AudioQueueEnqueueBuffer(mQueue, mBuffers[mIndex], 0, NULL);
        NSLog(@"fill audio queue buffer[%d]",mIndex);
        if(mIndex == 2) {
            isStartPlay = YES;
            mIndex = 0;
            status = AudioQueueStart(mQueue, NULL);
        }else {
            mIndex++;
        }
    }else {
        int ret = write(pip_fd[1], pcmData, mBufferByteSize);
        //NSLog(@"putAudioData to pipe %d",ret);
    }
    
}

@end
