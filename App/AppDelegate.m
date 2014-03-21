#import <Sparkle/Sparkle.h>

#import "AppDelegate.h"

#import "RHStatusItemView.h"
#import "NSAttributedString+hyperlinkFromString.h"
#import "KeenClient.h"

#import "Focus.h"
#import "InstallerManager.h"
#import "ConnectionManager.h"
#import "HelperTool.h"
#import "FocusHTTProxy.h"
#import "Config.h"

@interface AppDelegate ()

// TODO: Break this up!
@property (nonatomic, assign, readwrite) IBOutlet NSWindow *window;
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) FocusHTTProxy *httpProxy;
@property (strong, nonatomic) ConnectionManager *helperConnectionManager;
@property (strong, nonatomic) InstallerManager *installerManager;
@property (strong, nonatomic) Focus *focus;
@property (strong, nonatomic) NSMenu *menu;
@property (strong, nonatomic) IBOutlet NSButton *launchCheckbox;
@property (strong, nonatomic) IBOutlet NSMenu *contextMenu;
@property (strong, nonatomic) RHStatusItemView *statusItemView;
@property (strong, nonatomic) IBOutlet NSTextField *versionLabel;
@property (strong, nonatomic) IBOutlet NSTextFieldCell *websiteLabel;
@property (strong, nonatomic) IBOutlet NSMenuItem *focusAction;
@property (strong, nonatomic) IBOutlet NSButton *menuToggleCheckbox;
@property (strong, nonatomic) IBOutlet NSButton *monochromeIconCheckbox;
@property (strong, nonatomic) IBOutlet NSTableView *blockedSitesTableView;
@property (strong, nonatomic) IBOutlet NSArrayController *blockedSitesArrayController;
@property (strong, nonatomic) NSMutableArray *blockedSites;
@property (strong, nonatomic) NSUserDefaults *userDefaults;
@property (strong, nonatomic) IBOutlet NSButton *removeBlockedSite;
@property (strong, nonatomic) IBOutlet NSTextField *onFocusScript;
@property (strong, nonatomic) IBOutlet NSTextField *onUnfocusScript;

@end

@implementation AppDelegate

# pragma mark - System

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
    #pragma unused(note)
    [self initialize];
    assert(self.window != nil);
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    #pragma unused(notification)
    [self shutdown];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    #pragma unused(sender)
    return NO;
}

- (bool)windowShouldClose
{
    return NO;
}

# pragma mark - Setup methods

- (void)initialize
{
    self.userDefaults = [NSUserDefaults standardUserDefaults];

    long numRuns = [self increaseNumberOfRuns];
    
    [self setupInstallerManager];
    
    if (numRuns == 1) {
        [self firstRun];
    }
    
    [self setupFocus];
    [self setupSettingsDialog];
    [self setupMenuBarIcon];
    [self setupURLScheme];
    [self setupUpdater];
    [self setupAnalytics];
    
    self.helperConnectionManager = [ConnectionManager setup];
    self.httpProxy = [FocusHTTProxy setup];
    
    [self checkIfFocusOnStartup];
    
    [self trackEvent:@"load"];
}

- (void)setupUpdater
{
    SUUpdater *sparkle = [[SUUpdater alloc] init];
    sparkle.delegate = self;
    [sparkle checkForUpdatesInBackground];
}

// Setup the focus:// URL scheme to trigger events in Focus (currently focus/unfocus/uninstall). Check Focus help for more info
- (void)setupURLScheme
{
    NSAppleEventManager *em = [NSAppleEventManager sharedAppleEventManager];
    [em setEventHandler:self andSelector:@selector(getUrl:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

// Focus collects anonymous analytics on basic usage to improve the product
- (void)setupAnalytics
{
    [KeenClient sharedClientWithProjectId:KEEN_PROJECT_ID andWriteKey:KEEN_WRITE_KEY andReadKey:KEEN_READ_KEY];
    [KeenClient disableGeoLocation]; // without this the user gets a prompt
}

- (void)setupSettingsDialog
{
    // Setup checkbox state
    self.menuToggleCheckbox.state = [self.userDefaults boolForKey:@"menuIconTogglesFocus"];
    self.monochromeIconCheckbox.state = [self.userDefaults boolForKey:@"monochromeIcon"];
    self.launchCheckbox.state = [self.installerManager willAutoLaunch];
    
    [self setupAboutVersion];
    [self setupWebsiteLabel];
    [self setupBlockedSitesData];
    [self setupScriptHookFields];
    [self.removeBlockedSite setEnabled:NO];
}

// Installer manager manages complexity with helper tool & other install/uninstall tasks
- (void)setupInstallerManager
{
    self.installerManager = [InstallerManager setup];
    if (![self.installerManager installed]) {
        [self error:@"We're sorry, but Focus couldn't install it's helper correctly so we're exiting. Please try running Focus again to try re-installing."];
        return [[NSApplication sharedApplication] terminate:nil];
    }
}

- (void)setupFocus
{
    // Grab saved blocked sites and load them into focus
    NSArray *blockedHosts = [self.userDefaults arrayForKey:@"blockedSites"];
    self.focus = [[Focus alloc] initWithHosts:blockedHosts];
}

- (void)setupAboutVersion
{
    [self.versionLabel setStringValue:[NSString stringWithFormat:@"v%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]]];
}

- (void)setupScriptHookFields
{
    [self.onUnfocusScript setObjectValue:[self.userDefaults objectForKey:@"onUnfocusScript"]];
    [self.onFocusScript setObjectValue:[self.userDefaults objectForKey:@"onFocusScript"]];
}

- (void)setupBlockedSitesData
{
    for (NSString *host in self.focus.hosts) {
        [self.blockedSitesArrayController addObject:[[NSMutableDictionary alloc] initWithDictionary:@{@"name": host}]];
    }
    
    [self.blockedSitesTableView reloadData];
}

- (void)setupWebsiteLabel
{
    NSURL* url = [NSURL URLWithString:@"http://heyfocus.com/?utm_source=focus_about"];
    
    NSMutableAttributedString* string = [[NSMutableAttributedString alloc] init];
    [string appendAttributedString:[NSAttributedString hyperlinkFromString:@"http://heyfocus.com" withURL:url]];
    
    [self.websiteLabel setAttributedStringValue:string];
    [self.websiteLabel setAllowsEditingTextAttributes:YES];
    [self.websiteLabel setSelectable:YES];
    [self.websiteLabel setAlignment:NSCenterTextAlignment];
}

- (void)setupMenuBarIcon {
    
    if (self.statusItem != nil) return;
    
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:24];
    
    self.statusItem.highlightMode = NO;
    
    self.statusItemView = [[RHStatusItemView alloc] initWithStatusBarItem:self.statusItem];
    [self.statusItem setView:self.statusItemView];
    [self.statusItemView setRightMenu:self.contextMenu];
    [self.statusItemView setRightAction:@selector(rightClickMenu)];
    [self setStatusItemViewIconOff];
    
    if (self.menuToggleCheckbox.state) {
        [self.statusItemView setAction:@selector(toggleFocus)];
    } else {
        [self.statusItemView setAction:@selector(rightClickMenu)];
    }
}

// Keep track of the number of times Focus runs. Mostly useful for tracking first run for 1-time setup
- (long)increaseNumberOfRuns
{
    long numRuns = [self.userDefaults integerForKey:@"numRuns"];
    [self.userDefaults setInteger:++numRuns forKey:@"numRuns"];
    [self.userDefaults synchronize];
    LogMessageCompat(@"Number of runs = %ld", numRuns);
    return numRuns;
}

- (long)increaseNumberOfFocuses
{
    long numFocuses = [self.userDefaults integerForKey:@"numFocuses"];
    [self.userDefaults setInteger:++numFocuses forKey:@"numFocuses"];
    [self.userDefaults synchronize];
    LogMessageCompat(@"Number of focuses = %ld", numFocuses);
    return numFocuses;
}

- (void)checkIfFocusOnStartup
{
    // This shouldn't ever really happen unless Focus crashes
    if ([self.focus isFocusing]) {
        LogMessageCompat(@"Focus was active when it started. Deactivating");
        [self goUnfocus];
    }
}

- (void)firstRun
{
    LogMessageCompat(@"Performing first time run setup");
    [self.userDefaults setObject:[Focus getDefaultHosts] forKey:@"blockedSites"];
    [self.userDefaults synchronize];
}

# pragma mark - Focus

- (void)goFocus
{
    LogMessageCompat(@"goFocusing");
    
    [self trackEvent:@"focus"];
    
    [self increaseNumberOfFocuses];
    
    [self setStatusItemViewIconOn];
    
    if (![FocusHTTProxy isRunning]) {
        LogMessageCompat(@"HTTP Proxy IS NOT RUNNING...starting it!");
        [self.httpProxy start];
    }
    
    [self.helperConnectionManager connectAndExecuteCommandBlock:^(NSError *connectError) {
        if (connectError != nil) {
            [self error:[NSString stringWithFormat:@"Unable to connect to helper: %@", connectError]];
            [self setStatusItemViewIconOff];
            return;
        }
        
        [[self.helperConnectionManager.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
            [self error:[NSString stringWithFormat:@"Proxy error: %@", proxyError]];
        }] focus:self.installerManager.authorization blockedHosts:self.focus.hosts withReply:^(NSError *commandError) {
            if (commandError != nil) {
                [self error:[NSString stringWithFormat:@"Error response from helper: %@", commandError]];
            } else {
                NSString *script = [self.userDefaults objectForKey:@"onFocusScript"];
                if (script) {
                    [self runScript:script];
                }
            }
        }];
    }];
}

- (void)goUnfocus
{
    LogMessageCompat(@"goUnfocusing");
    
    // This seems like the least bad place to interrupt a user for a productivity app about focusing :)
    long numFocuses = [self.userDefaults integerForKey:@"numFocuses"];
    if (numFocuses == 3) {
        [self promptForAutoStart];
    }
    
    [self trackEvent:@"unfocus"];
    
    [self setStatusItemViewIconOff];
    
    [self.helperConnectionManager connectAndExecuteCommandBlock:^(NSError *connectError) {
        if (connectError != nil) {
            [self error:[NSString stringWithFormat:@"Unable to connect to helper: %@", connectError]];
            [self setStatusItemViewIconOn];
            return;
        }
        
        [[self.helperConnectionManager.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
            [self error:[NSString stringWithFormat:@"Proxy error: %@", proxyError]];
        }] unfocus:self.installerManager.authorization withReply:^(NSError *commandError) {
            if (commandError != nil) {
                [self error:[NSString stringWithFormat:@"Error response from helper: %@", commandError]];
            } else {
                NSString *script = [self.userDefaults objectForKey:@"onUnfocusScript"];
                if (script) {
                    [self runScript:script];
                }
            }
        }];
    }];
}


- (void)toggleFocus
{
    if ([self.statusItemView.toolTip isEqualToString:@"Focus"]) {
        [self goFocus];
    } else if ([self.statusItemView.toolTip isEqualToString:@"Unfocus"]) {
        [self goUnfocus];
    } else {
        [self error:@"Unknown Focus state"];
    }
}

- (void)shutdown
{
    LogMessageCompat(@"Shutting down");
    
    if ([self.focus isFocusing]) {
        [self goUnfocus];
    }
    
    [self.httpProxy stop];
}



- (void)uninstall
{
    [self goUnfocus];
    
    [self trackEvent:@"uninstall"];
    
    [self resetUserDefaults];
    
    // Uninstall auto launch
    [self.installerManager uninstallAutoLaunch];
    
    [self.helperConnectionManager connectAndExecuteCommandBlock:^(NSError *connectError) {
        if (connectError != nil) {
            [self error:[NSString stringWithFormat:@"Unable to connect to helper: %@", connectError]];
            self.statusItem.title = @"Unfocus";
            [self setStatusItemViewIconOn];
            return;
        }
        
        [[self.helperConnectionManager.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
            [self error:[NSString stringWithFormat:@"Proxy error: %@", proxyError]];
        }] uninstall:self.installerManager.authorization withReply:^(NSError *commandError) {
#pragma unused(commandError)
            [[NSApplication sharedApplication] terminate:nil];
        }];
    }];
}

// Uninstall just the helper—useful for reinstalling the helper when it starts back up
// Otherwise you probably want [self uninstall]
- (void)uninstallHelper
{
    [self.helperConnectionManager connectAndExecuteCommandBlock:^(NSError *connectError) {
        if (connectError != nil) {
            [self error:[NSString stringWithFormat:@"Unable to connect to helper: %@", connectError]];
            return;
        }
        
        [[self.helperConnectionManager.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
            [self error:[NSString stringWithFormat:@"Proxy error: %@", proxyError]];
        }] uninstall:self.installerManager.authorization withReply:^(NSError *commandError) {
#pragma unused(commandError)
            if (commandError == nil) {
                NSLog(@"Helper tool successfully uninstalled");
            } else {
                [self error:@"There was a problem while trying to upgrade Focus. Please try again. If that doesn't work, you can re-open the app and click Uninstall in the menu (this will remove your settings). Then run the latest version. Sorry for any inconvenience."];
            }
        }];
    }];
}

#pragma mark - UI methods

- (void)promptForAutoStart
{
    if ([self.installerManager willAutoLaunch]) {
        NSLog(@"Focus will already auto-launch, skipping...");
        return;
    }
    
    NSAlert *alertBox = [[NSAlert alloc] init];
    [alertBox setMessageText:@"Start Focus automatically?"];
    [alertBox setInformativeText:@"Do you want to start Focus automatically when your computer boots? (you can always change this later)"];
    [alertBox addButtonWithTitle:@"OK"];
    [alertBox addButtonWithTitle:@"Cancel"];
    [alertBox setAlertStyle:NSWarningAlertStyle];
    NSInteger buttonClicked = [alertBox runModal];
    
    if (buttonClicked == NSAlertFirstButtonReturn) {
        NSLog(@"User does want to start focus automatically");
        [self.installerManager installAutoLaunch];
        self.launchCheckbox.state = [self.installerManager willAutoLaunch];
    }

}

- (void)saveBlockedSitesData
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        
        NSArray *blockedSites = [self.blockedSitesArrayController arrangedObjects];
        NSMutableArray *container = [[NSMutableArray alloc] init];
        
        for (NSDictionary *host in blockedSites)
        {
            [container addObject:[host objectForKey:@"name"]];
        }
        
        [self.userDefaults setObject:container forKey:@"blockedSites"];
        [self.userDefaults synchronize];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.focus.hosts = container;
            
            if ([self.focus isFocusing]) {
                [self toggleFocus];
                [self toggleFocus];
            }
        });
    });
}

- (void)resetBlockedSitesData
{
    NSRange range = NSMakeRange(0, [[self.blockedSitesArrayController arrangedObjects] count]);
    [self.blockedSitesArrayController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:range]];
}

- (void)setStatusItemViewIconOff
{
    [self.statusItemView setImage:[NSImage imageNamed:@"menu-icon-off"]];
    [self.statusItemView setAlternateImage:[NSImage imageNamed:@"menu-icon-off-alt"]];
    [self.statusItemView setToolTip:@"Focus"];
    [self.focusAction setTitle:@"Focus"];
    self.statusItem.title = @"Focus";
}

- (void)setStatusItemViewIconOn
{
    if ([self.userDefaults boolForKey:@"monochromeIcon"]) {
        [self.statusItemView setImage:[NSImage imageNamed:@"menu-icon-on-gray"]];
    } else {
        [self.statusItemView setImage:[NSImage imageNamed:@"menu-icon-on"]];
    }
    
    [self.statusItemView setAlternateImage:[NSImage imageNamed:@"menu-icon-off-alt"]];
    [self.statusItemView setToolTip:@"Unfocus"];
    [self.focusAction setTitle:@"Unfocus"];
    self.statusItem.title = @"Unfocus";
}

- (void)rightClickMenu
{
    [self.statusItemView popUpRightMenu];
}

-(void)turnOnMenuIconTogglesFocus
{
    [self.userDefaults setObject:@YES forKey:@"menuIconTogglesFocus"];
    [self.userDefaults synchronize];
    [self.statusItemView setAction:@selector(toggleFocus)];
}

-(void)turnOffMenuIconTogglesFocus
{
    [self.userDefaults setObject:@NO forKey:@"menuIconTogglesFocus"];
    [self.userDefaults synchronize];
    [self.statusItemView setAction:@selector(rightClickMenu)];
}

- (void)turnMonochromeIconOn
{
    [self.userDefaults setObject:@YES forKey:@"monochromeIcon"];
    [self.userDefaults synchronize];
    
    if ([self.focus isFocusing]) {
        [self.statusItemView setImage:[NSImage imageNamed:@"menu-icon-on-gray"]];
    }
}

- (void)turnMonochromeIconOff
{
    [self.userDefaults setObject:@NO forKey:@"monochromeIcon"];
    [self.userDefaults synchronize];
    
    if ([self.focus isFocusing]) {
        [self.statusItemView setImage:[NSImage imageNamed:@"menu-icon-on"]];
    }
}

# pragma mark - IBAction

- (IBAction)clickedFocusMenuItem:(id)sender {
#pragma unused(sender)
    [self toggleFocus];
}

- (IBAction)clickedToggleFocusMenuIconCheckbox:(NSButton *)checkbox {
    if (checkbox.state) {
        [self turnOnMenuIconTogglesFocus];
    } else {
        [self turnOffMenuIconTogglesFocus];
    }
}

- (IBAction)clickedMonochromeIconCheckbox:(NSButton *)checkbox {
    if (checkbox.state) {
        [self turnMonochromeIconOn];
    } else {
        [self turnMonochromeIconOff];
    }
}

- (IBAction)toggledLaunchAtStartupCheckbox:(NSButton *)checkbox
{
    bool isChecked = [checkbox state];
    
    if (isChecked) {
        [self.installerManager installAutoLaunch];
    } else {
        [self.installerManager uninstallAutoLaunch];
    }
}

- (IBAction)clickedHelp:(NSMenuItem *)sender {
#pragma unused(sender)
    [self showHelp];
}

- (void)showHelp
{
    NSURL * helpFile = [[NSBundle mainBundle] URLForResource:@"help" withExtension:@"html"];
    [[NSWorkspace sharedWorkspace] openURL:helpFile];
}

- (void)clickedUninstallFocus {
    
    NSAlert *alertBox = [[NSAlert alloc] init];
    [alertBox setMessageText:@"Are you sure you want to uninstall Focus?"];
    [alertBox setInformativeText:@"We will deactivate Focus, close it & uninstall, are you sure you want to continue?"];
    [alertBox addButtonWithTitle:@"OK"];
    [alertBox addButtonWithTitle:@"Cancel"];
    [alertBox setAlertStyle:NSWarningAlertStyle];
    NSInteger buttonClicked = [alertBox runModal];
    
    if (buttonClicked == NSAlertFirstButtonReturn) {
        [self.window close];
        [self uninstall];
    }
}

- (IBAction)clickedSettings:(id)sender {
#pragma unused(sender)
    [self trackEvent:@"settings"];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)clickedExit:(id)sender {
#pragma unused(sender)
    [self applicationWillTerminate:nil];
    exit(0);
}

- (IBAction)clickedAddBlockedSiteButton:(NSButton *)button {
#pragma unused(button)
    LogMessageCompat(@"Clicked add site button");
    
    [self.window makeFirstResponder:nil];
    
    NSArray *blockedSites = [self.blockedSitesArrayController arrangedObjects];
    unsigned long lastRowIndex = [blockedSites count];
    
    [self.blockedSitesArrayController addObject:[[NSMutableDictionary alloc] initWithDictionary:@{@"name": @""}]];
    [self.blockedSitesTableView scrollToEndOfDocument:self];
    [self.blockedSitesTableView editColumn:0 row:(NSInteger)lastRowIndex withEvent:nil select:NO];
}

- (IBAction)clickedRemoveBlockedSiteButton:(NSButton *)button {
#pragma unused(button)
    
    LogMessageCompat(@"Clicked remove site button");
    [self.blockedSitesArrayController removeObjectsAtArrangedObjectIndexes:[self.blockedSitesTableView selectedRowIndexes]];
    [self.blockedSitesTableView deselectAll:self];
    
    [self saveBlockedSitesData];
}

- (IBAction)clickedResetToDefaultsBlockedSitesButton:(NSButton *)button {
#pragma unused(button)
    
    NSAlert *alertBox = [[NSAlert alloc] init];
    [alertBox setMessageText:@"Are you sure you want to reset your blocked sites?"];
    [alertBox setInformativeText:@"All current sites will be removed and replaced with what is shipped by default. This can't be undone."];
    [alertBox addButtonWithTitle:@"OK"];
    [alertBox addButtonWithTitle:@"Cancel"];
    [alertBox setAlertStyle:NSWarningAlertStyle];
    NSInteger buttonClicked = [alertBox runModal];
    
    if (buttonClicked == NSAlertFirstButtonReturn) {
        LogMessageCompat(@"Resetting to blocked sites defaults");
        
        self.focus.hosts = [Focus getDefaultHosts];
        [self resetBlockedSitesData];
        [self setupBlockedSitesData];
        [self saveBlockedSitesData];
    }
}

- (IBAction)onFocusScriptButtonClicked:(NSButton *)sender {
#pragma unused(sender)

    NSString *script = [self getExecutableFromFileDialog];

    if (script) {
        [self.onFocusScript setObjectValue:script];
        [self.userDefaults setObject:script forKey:@"onFocusScript"];
        [self.userDefaults synchronize];
    }

    NSLog(@"Setting focus script = %@", [self.onFocusScript objectValue]);
}


- (IBAction)onUnfocusScriptButtonClicked:(NSButton *)sender {
#pragma unused(sender)

    NSString *script = [self getExecutableFromFileDialog];

    if (script) {
        [self.onUnfocusScript setObjectValue:script];
        [self.userDefaults setObject:script forKey:@"onUnfocusScript"];
        [self.userDefaults synchronize];
    }

    NSLog(@"Setting unfocus script = %@", [self.onUnfocusScript objectValue]);
}

# pragma mark - Table View

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
#pragma unused(notification)
    long selectedRow = [self.blockedSitesTableView selectedRow];
    if (selectedRow >= 0) {
        [self.removeBlockedSite setEnabled:YES];
    } else {
        [self.removeBlockedSite setEnabled:NO];
    }
}


- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    NSTextView *aView = [userInfo valueForKey:@"NSFieldEditor"];

    NSString *savedObject = [aView string];
    long selectedRow = [self.blockedSitesTableView selectedRow];

    bool empty = [[savedObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0;

    if (empty) {
        LogMessageCompat(@"Row is empty, let's delete it");
        [self.blockedSitesArrayController removeObjectAtArrangedObjectIndex:(NSUInteger)selectedRow];
    } else {
        [self saveBlockedSitesData];
    }
}

- (void)controlTextDidChange:(NSNotification *)notification {
    NSTextField *textField = [notification object];

    // TODO: Is there a better way to handle multiple tagField's than tag's?
    
    // onFocusScript text box
    if (textField.tag == 445) {
        [self.userDefaults setObject:[textField objectValue] forKey:@"onFocusScript"];
        [self.userDefaults synchronize];

    // onUnfocusScript text box
    } else if (textField.tag == 446) {
        [self.userDefaults setObject:[textField objectValue] forKey:@"onUnfocusScript"];
        [self.userDefaults synchronize];
    }
}

# pragma mark - Sparkle Delegates

- (void)updater:(SUUpdater *)updater willInstallUpdate:(SUAppcastItem *)update
{
#pragma unused(updater)
    // When updating, if the property "updateHelper" is true, uninstall the helper before we restart
    // so that it will be re-installed next time
    NSString *updateHelper = [update.propertiesDictionary objectForKey:@"updateHelper"];
    if ([updateHelper isEqualToString:@"true"]) {
        NSLog(@"We're updating the helper. Remove it so we can re-install on relaunch");
        [self uninstallHelper];
    }
}

# pragma mark - URL Scheme

- (void)getUrl:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
#pragma unused(replyEvent)

    NSString *urlStr = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSString *action = [[url host] lowercaseString];

    // hooks for focus://<action>
    if ([action isEqualToString:@"focus"]) {
        [self goFocus];
    } else if ([action isEqualToString:@"unfocus"]) {
        [self goUnfocus];
    } else if ([action isEqualToString:@"uninstall"]) {
        [self clickedUninstallFocus];
    }
}

# pragma mark - Utils

// TODO Most of these should be split out as separate libs

- (void)trackEvent:(NSString *)eventName
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:eventName, @"event", nil];
        [[KeenClient sharedClient] addEvent:event toEventCollection:KEEN_COLLECTION error:nil];
        [[KeenClient sharedClient] uploadWithFinishedBlock:nil];
    });
}

- (void)error:(NSString *)msg
{
    LogMessageCompat(@"ERROR = %@", msg);
    
    // TODO: Add more detailed error tracking here without leaking any private data...
    [self trackEvent:@"error"];
    
    NSAlert *alertBox = [[NSAlert alloc] init];
    [alertBox setMessageText:@"An Error Occurred"];
    [alertBox setInformativeText:msg];
    [alertBox addButtonWithTitle:@"OK"];
    [alertBox runModal];
}

- (void)resetUserDefaults
{
    NSString *domainName = [[NSBundle mainBundle] bundleIdentifier];
    [self.userDefaults removePersistentDomainForName:domainName];
}

- (NSString *)getExecutableFromFileDialog {
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    NSInteger result = [panel runModal];
    
    if (result == NSOKButton) {
        return [[panel URL] path];
    }
    
    return nil;
}

// TODO Is there any way to make this safer?
-(void)runScript:(NSString*)scriptName
{
    NSString *contents = [[NSString stringWithContentsOfFile:scriptName encoding:NSUTF8StringEncoding error:NULL] lowercaseString];
    
    if ([contents rangeOfString:@"focus://"].location != NSNotFound) {
        [self error:@"Focus & Unfocus scripts cannot contain the string 'focus://'. You're not allowed to change Focus state from these scripts, otherwise it might result in an infinite loop."];
        return;
    }
    
    NSLog(@"Running script = %@", scriptName);
    
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    
    [task setArguments:@[scriptName]];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];
    return;
    
    NSData *data;
    data = [file readDataToEndOfFile];
    
    NSString *string;
    string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    
    NSLog (@"script returned:\n%@", string);
}

@end
