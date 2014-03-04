//
//  RHStatusItemView.m
//
//  Created by Richard Heard on 9/10/12.
//  Copyright (c) 2012 Richard Heard. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions
//  are met:
//  1. Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright
//  notice, this list of conditions and the following disclaimer in the
//  documentation and/or other materials provided with the distribution.
//  3. The name of the author may not be used to endorse or promote products
//  derived from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
//  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
//  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


static CGFloat RHStatusItemViewImageHPadding = 4.0f;
static CGFloat RHStatusItemViewImageVPadding = 3.0f;


#import "RHStatusItemView.h"

@implementation RHStatusItemView

@synthesize statusItem;

@synthesize image;
@synthesize alternateImage;

@synthesize target;
@synthesize action;
@synthesize rightAction;

@synthesize menu;
@synthesize rightMenu;


#pragma mark - init
-(id)init{ return [self initWithStatusBarItem:nil]; }
-(id)initWithFrame:(NSRect)frameRect {
#pragma unused(frameRect)
    return [self initWithStatusBarItem:nil];
}

-(id)initWithStatusBarItem:(NSStatusItem*)aStatusItem{
    if (!aStatusItem) [NSException raise:NSInvalidArgumentException format:@"-[%@ %@] statusItem should not be nil!", NSStringFromClass(self.class), NSStringFromSelector(_cmd)];
    
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        self.statusItem = aStatusItem;
    }
    
    return self;
}

#pragma mark - NSView
- (void)drawRect:(NSRect)rect {

#pragma unused(rect)
    BOOL highlighted = isMouseDown || isMenuVisible;
    
    // Draw status bar background, highlighted if menu is showing
    [self.statusItem drawStatusBarBackgroundInRect:[self bounds] withHighlight:highlighted];

    NSRect imageRect = NSInsetRect(self.bounds, RHStatusItemViewImageHPadding, RHStatusItemViewImageVPadding);
    imageRect.origin.y++; //move it up one pix
    
    if (highlighted){
        [self.alternateImage drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
    } else {
        [self.image drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
    }
}


#pragma mark - mouse tracking

//left
-(void)mouseDown:(NSEvent *)theEvent{
#pragma unused(theEvent)
    isMouseDown = YES;
    [self setNeedsDisplay];
}

- (void)mouseUp:(NSEvent *)event {
    if (!isMouseDown) return; //if showing a menu, the mouse down event dismisses the menu before we see it, so this is a nice way not to re-show the menu on the subsequent mouse up

    if([event modifierFlags] & NSControlKeyMask) {
        if (![NSApp sendAction:self.rightAction to:self.target from:self]){
            [self popUpMenu];
        }
    } else {
        if (![NSApp sendAction:self.action to:self.target from:self]){
            [self popUpMenu];
        }
    }

    isMouseDown = NO;
    [self setNeedsDisplay];
    
}

//right
-(void)rightMouseDown:(NSEvent *)theEvent{
#pragma unused(theEvent)
    isMouseDown = YES;
    [self setNeedsDisplay];
}

- (void)rightMouseUp:(NSEvent *)event {
#pragma unused(event)
    if (!isMouseDown) return; //if showing a menu, the mouse down event dismisses the menu before we see it, so this is a nice way not to re-show the menu on the subsequent mouse up
    
    if (![NSApp sendAction:self.rightAction to:self.target from:self]){
        if (self.rightMenu){
            [self popUpRightMenu];
        } else {
            [self popUpMenu];
        }
    }
    isMouseDown = NO;
    [self setNeedsDisplay];
    
}


#pragma mark - Menu showing
-(void)popUpMenu{
    [self popUpMenu:self.menu];
}

-(void)popUpRightMenu{
    [self popUpMenu:self.rightMenu];
}

-(void)popUpMenu:(NSMenu*)aMenu {
    if (aMenu){
        //register for menu did open and close notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuWillOpen:) name:NSMenuDidBeginTrackingNotification object:aMenu];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuDidClose:) name:NSMenuDidEndTrackingNotification object:aMenu];
        
        [statusItem popUpStatusItemMenu:aMenu];
    }
}


#pragma mark - NSMenuDidBeginTrackingNotification
-(void)menuWillOpen:(NSNotification *)notification{
    isMenuVisible = YES;
    [self setNeedsDisplay];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSMenuDidBeginTrackingNotification object:notification.object];
}


#pragma mark - NSMenuDidEndTrackingNotification
-(void)menuDidClose:(NSNotification *)notification{
    isMenuVisible = NO;
    [self setNeedsDisplay];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSMenuDidEndTrackingNotification object:notification.object];

}

@end
