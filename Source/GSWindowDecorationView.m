/** <title>GSWindowDecorationView</title>

   Copyright (C) 2004 Free Software Foundation, Inc.

   Author: Alexander Malmberg <alexander@malmberg.org>
   Date: 2004-03-24

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the 
   Free Software Foundation, 51 Franklin Street, Fifth Floor, 
   Boston, MA 02110-1301, USA.
*/

#include "GSWindowDecorationView.h"

#include <Foundation/NSException.h>

#include "AppKit/NSColor.h"
#include "AppKit/NSWindow.h"
#include "GNUstepGUI/GSDisplayServer.h"
#include "GNUstepGUI/GSTheme.h"

#include "NSToolbarFrameworkPrivate.h"

@implementation GSWindowDecorationView

+ (id<GSWindowDecorator>) windowDecorator
{
  if ([GSCurrentServer() handlesWindowDecorations])
    return [GSBackendWindowDecorationView self];
  else
    return [GSStandardWindowDecorationView self];
}


+ (id) newWindowDecorationViewWithFrame: (NSRect)frame
				 window: (NSWindow *)aWindow
{
  return [[self alloc] initWithFrame: frame
			      window: aWindow];
}


+ (void) offsets: (float *)l : (float *)r : (float *)t : (float *)b
    forStyleMask: (unsigned int)style
{
  [self subclassResponsibility: _cmd];
}

+ (NSRect) contentRectForFrameRect: (NSRect)aRect
			 styleMask: (unsigned int)aStyle
{
  float t, b, l, r;

  [self offsets: &l : &r : &t : &b forStyleMask: aStyle];
  aRect.size.width -= l + r;
  aRect.size.height -= t + b;
  aRect.origin.x += l;
  aRect.origin.y += b;
  return aRect;
}

+ (NSRect) frameRectForContentRect: (NSRect)aRect
			 styleMask: (unsigned int)aStyle
{
  float t, b, l, r;

  [self offsets: &l : &r : &t : &b forStyleMask: aStyle];
  aRect.size.width += l + r;
  aRect.size.height += t + b;
  aRect.origin.x -= l;
  aRect.origin.y -= b;
  return aRect;
}

+ (float) minFrameWidthWithTitle: (NSString *)aTitle
		       styleMask: (unsigned int)aStyle
{
  [self subclassResponsibility: _cmd];
  return 0.0;
}


- (id) initWithFrame: (NSRect)frame
{
  NSAssert(NO, @"Tried to create GSWindowDecorationView without a window!");
  return nil;
}

- (id) initWithFrame: (NSRect)frame
	      window: (NSWindow *)w
{
  self = [super initWithFrame: frame];
  if (self != nil)
    {
      window = w;
      // Content rect will be everything apart from the border
      // that is including menu, toolbar and the like.
      contentRect = [isa contentRectForFrameRect: frame
                          styleMask: [w styleMask]];
    }
  return self;
}

- (NSRect) contentRectForFrameRect: (NSRect)aRect
                         styleMask: (unsigned int)aStyle
{
  NSRect content = [isa contentRectForFrameRect: aRect
                          styleMask: aStyle];
  NSToolbar *tb = [_window toolbar];

  // TODO: Handle toolbar and others
  if ([tb isVisible])
    {
      GSToolbarView *tv = [tb _toolbarView];

      content.size.height -= [tv _heightFromLayout];
    }

  return content;
}

- (NSRect) frameRectForContentRect: (NSRect)aRect
                         styleMask: (unsigned int)aStyle
{
  NSToolbar *tb = [_window toolbar];

  // TODO: Handle toolbar and others
  if ([tb isVisible])
    {
      GSToolbarView *tv = [tb _toolbarView];

      aRect.size.height += [tv _heightFromLayout];
    }

  return [isa frameRectForContentRect: aRect
              styleMask: aStyle];
}

#if 0
- (void) removeSubview: (NSView*)aView
{
  RETAIN(aView);
  /*
   * If the content view is removed, we must let the window know.
   */
  [super removeSubview: aView];
  if (aView == [_window contentView])
    {
      [_window setContentView: nil];
    }
  RELEASE(aView);
}
#endif

- (void) setBackgroundColor: (NSColor *)color
{
  [self setNeedsDisplayInRect: contentRect];
}

- (void) setContentView: (NSView *)contentView
{
  NSSize oldSize;

  [contentView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
  [self addSubview: contentView];

  oldSize = [contentView frame].size;
  oldSize.width += _frame.size.width - contentRect.size.width;
  oldSize.height += _frame.size.height - contentRect.size.height;
  [contentView resizeWithOldSuperviewSize: oldSize];
  [contentView setFrameOrigin: NSMakePoint(contentRect.origin.x,
					   contentRect.origin.y)];
}

- (void) setDocumentEdited: (BOOL)flag
{
  documentEdited = flag;
  if (windowNumber)
    [GSServerForWindow(window) docedited: documentEdited : windowNumber];
}

/*
 * Special setFrame: implementation - a minimal autoresize mechanism
 */
- (void) setFrame: (NSRect)frameRect
{
  NSSize oldSize = _frame.size;
  NSView *cv = [_window contentView];
  NSToolbar *tb = [_window toolbar];

  _autoresizes_subviews = NO;
  [super setFrame: frameRect];

  contentRect = [isa contentRectForFrameRect: frameRect
                      styleMask: [window styleMask]];

  // Safety Check.
  [cv setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
  [cv resizeWithOldSuperviewSize: oldSize];

  // FIXME: Should resize all subviews
  if ([tb isVisible])
    {
      GSToolbarView *tv = [tb _toolbarView];
      NSRect contentViewFrame = [cv frame];
      float newToolbarViewHeight;
      
      [tv setFrameSize: NSMakeSize(contentViewFrame.size.width, 100)];
      // Will recalculate the layout
      [tv _reload];
      newToolbarViewHeight = [tv _heightFromLayout];
      [tv setFrame: NSMakeRect(
              contentViewFrame.origin.x,
              contentViewFrame.size.height, 
              contentViewFrame.size.width, 
              newToolbarViewHeight)];
    }
}

- (void) setInputState: (int)state
{
  inputState = state;
  if (windowNumber)
    [GSServerForWindow(window) setinputstate: inputState : windowNumber];
}

- (void) setTitle: (NSString *)title
{
  if (windowNumber)
    [GSServerForWindow(window) titlewindow: title : windowNumber];
}

- (void) setWindowNumber: (int)theWindowNumber
{
  windowNumber = theWindowNumber;
  if (!windowNumber)
    return;

  [GSServerForWindow(window) titlewindow: [window title] : windowNumber];
  [GSServerForWindow(window) setinputstate: inputState : windowNumber];
  [GSServerForWindow(window) docedited: documentEdited : windowNumber];
}


- (BOOL) isOpaque
{
  return YES;
}

- (void) drawRect: (NSRect)rect
{
  if (NSIntersectsRect(rect, contentRect))
    {
      [[GSTheme theme] drawWindowBackground: contentRect view: self];
    }
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  NSAssert(NO, @"The top-level window view should never be encoded.");
  return nil;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  NSAssert(NO, @"The top-level window view should never be encoded.");
}

@end

@implementation GSWindowDecorationView (ToolbarPrivate)

- (void) addToolbarView: (GSToolbarView*)toolbarView
{
  NSView *contentView = [window contentView];
  NSRect contentViewFrame = [contentView frame];
  float newToolbarViewHeight;

  [toolbarView setFrameSize: NSMakeSize(contentViewFrame.size.width, 100)];
  // Will recalculate the layout
  [toolbarView _reload];
  newToolbarViewHeight = [toolbarView _heightFromLayout];
  
  // Plug the toolbar view
  [toolbarView setFrame: NSMakeRect(
          contentViewFrame.origin.x,
          contentViewFrame.size.height - newToolbarViewHeight, 
          contentViewFrame.size.width, 
          newToolbarViewHeight)];
  [self addSubview: toolbarView];
  
  // Resize the content view
  contentViewFrame.size.height -= newToolbarViewHeight;
  [contentView setFrame: contentViewFrame];
}

- (void) removeToolbarView: (GSToolbarView *)toolbarView
{
  NSView *contentView = [window contentView];
  NSRect contentViewFrame = [contentView frame];
  float toolbarViewHeight = [toolbarView frame].size.height;
  
  // Unplug the toolbar view
  [toolbarView removeFromSuperviewWithoutNeedingDisplay];
  
  // Resize the content view
  contentViewFrame.size.height += toolbarViewHeight;
  [contentView setFrame: contentViewFrame];
}

- (void) adjustToolbarView: (GSToolbarView *)toolbarView
{
  // Frame and height
  NSRect toolbarViewFrame = [toolbarView frame];
  float toolbarViewHeight = toolbarViewFrame.size.height;
  float newToolbarViewHeight = [toolbarView _heightFromLayout];
  
  if (toolbarViewHeight != newToolbarViewHeight)
    {
      NSView *contentView = [window contentView];
      NSRect contentViewFrame = [contentView frame];
      
      [toolbarView setFrame: NSMakeRect(
              toolbarViewFrame.origin.x,
              toolbarViewFrame.origin.y + (toolbarViewHeight - newToolbarViewHeight),
              toolbarViewFrame.size.width, 
              newToolbarViewHeight)];
      
      // Resize the content view
      contentViewFrame.size.height += toolbarViewHeight - newToolbarViewHeight;
      [contentView setFrame: contentViewFrame];

      // Redisplay the window
      [window display];
    }
}

@end

@implementation GSBackendWindowDecorationView

+ (void) offsets: (float *)l : (float *)r : (float *)t : (float *)b
    forStyleMask: (unsigned int)style
{
  [GSCurrentServer() styleoffsets: l : r : t : b : style];
}

+ (float) minFrameWidthWithTitle: (NSString *)aTitle
		       styleMask: (unsigned int)aStyle
{
  /* TODO: we could at least guess... */
  return 0.0;
}

@end

