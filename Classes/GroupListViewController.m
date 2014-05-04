//
//  GroupListViewController.m
//  GpsSketchingSample
//
//  Created by Yi Wang on 5/4/14.
//
//

#import "GroupListViewController.h"
#import <Firebase/Firebase.h>
#import "GpsSketchingSampleViewController.h"

@interface GroupListViewController ()

@property (nonatomic, strong) NSMutableArray *groupList;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic) NSInteger currentSelectedIndex;
@property (nonatomic) NSString* currentSelectedName;
@end

@implementation GroupListViewController



- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.groupList = [NSMutableArray array];
    
    Firebase *groupBase = [[Firebase alloc] initWithUrl:@"https://grolo.firebaseio.com/trips"];
    [groupBase observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        
        self.groupList = snapshot.value;
        [self.tableView reloadData];
    }];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.groupList.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"groupListCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"groupListCell"];
    }
    
    NSDictionary *dict = [self.groupList objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [dict objectForKey:@"name"];
    
    NSArray *users = [dict objectForKey:@"users"];
    
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%i Users", users.count];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.currentSelectedIndex = indexPath.row;
    NSDictionary *dict = [self.groupList objectAtIndex:indexPath.row];
    
    self.currentSelectedName = [dict objectForKey:@"name"];

    [self performSegueWithIdentifier:@"group" sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"group"])
    {
        GpsSketchingSampleViewController *vc = segue.destinationViewController;
        vc.currentGroupId = self.currentSelectedIndex;
        vc.currentGroupName = self.currentSelectedName;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
