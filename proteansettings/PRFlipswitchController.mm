#import <Preferences/Preferences.h>
#import <UIKit/UISearchBar2.h>
#import "PRFSSelector.h"
#import <flipswitch/Flipswitch.h>

#define PLIST_NAME @"/var/mobile/Library/Preferences/com.efrederickson.protean.settings.plist"

#define isPad() ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
#define iPhoneTemplatePath @"/Library/Protean/FlipswitchTemplates/IconTemplate.bundle"
#define iPadTemplatePath @"/Library/Protean/FlipswitchTemplates/IconTemplate~iPad.bundle"
#define TemplatePath (isPad() ? iPadTemplatePath : iPhoneTemplatePath)

@interface PSViewController (Protean)
-(void) viewDidLoad;
-(void) viewWillDisappear:(BOOL)animated;
-(void) setView:(id)view;
-(void) setTitle:(NSString*)title;
@end
@interface UIImage (Protean)
+ (UIImage*)imageNamed:(NSString *)imageName inBundle:(NSBundle*)bundle;
- (UIImage*) _flatImageWithColor: (UIColor*) color;
@end

@interface PRFlipswitchController : PSViewController <UITableViewDelegate, UITableViewDataSource>
{
	UITableView* _tableView;
}
@end

NSMutableArray *flipswitches;

void updateFlipswitches()
{
    flipswitches = [NSMutableArray array];
    FSSwitchPanel *fsp = [FSSwitchPanel sharedPanel];
    NSBundle *templateBundle = [NSBundle bundleWithPath:TemplatePath];
    
    for (NSString *identifier in fsp.sortedSwitchIdentifiers) {
        [flipswitches addObject:@{
                                  @"title": [[FSSwitchPanel sharedPanel] titleForSwitchIdentifier:identifier],
                                  @"icon": [[[FSSwitchPanel sharedPanel] imageOfSwitchState:[[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:identifier] controlState:UIControlStateNormal forSwitchIdentifier:identifier usingTemplate:templateBundle] _flatImageWithColor:[UIColor blackColor]],
                                  @"identifier": identifier
                                  }];
    }
}

@implementation PRFlipswitchController

-(id)init
{
	if (!(self = [super init])) return nil;
	
	CGRect bounds = [[UIScreen mainScreen] bounds];
	
	_tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, bounds.size.height) style:UITableViewStyleGrouped];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_tableView.delegate = self;
	_tableView.dataSource = self;
	
	return self;
}

-(void)viewDidLoad
{
	((UIViewController *)self).title = @"Flipswitches";
	
	[self setView:_tableView];
    
	[super viewDidLoad];
}

-(void) viewWillAppear:(BOOL) animated
{
    updateFlipswitches();
    [_tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

-(void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
	UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    
	// Need to mimic what PSListController does when it handles didSelectRowAtIndexPath
	// otherwise the child controller won't load
	PRFSSelector* controller = [[PRFSSelector alloc]
                                            initWithFSName:cell.textLabel.text
                                            identifier:flipswitches[indexPath.row][@"identifier"]
                                            ];
	controller.rootController = self.rootController;
	controller.parentController = self;
	
	[self pushController:controller];
	[tableView deselectRowAtIndexPath:indexPath animated:true];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return flipswitches.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (cell == nil)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
 
    cell.textLabel.text = flipswitches[indexPath.row][@"title"];
    cell.imageView.image = flipswitches[indexPath.row][@"icon"];
    
    return cell;
}

@end