#import <Preferences/Preferences.h>

@interface PRBTIconSelectorController : PSViewController <UITableViewDelegate, UITableViewDataSource>
{
	NSString* _appName;
	NSString* _identifier;
	UITableView* _tableView;
}
-(id)initWithAppName:(NSString*)appName identifier:(NSString*)identifier;
@end