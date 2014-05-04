// Copyright 2012 ESRI
//
// All rights reserved under the copyright laws of the United States
// and applicable international laws, treaties, and conventions.
//
// You may freely redistribute and use this sample code, with or
// without modification, provided you include the original copyright
// notice and use restrictions.
//
// See the use restrictions at http://help.arcgis.com/en/sdk/10.0/usageRestrictions.htm
//

#import "GpsSketchingSampleViewController.h"
#import <CoreLocation/CoreLocation.h>
#import "Parameters.h"
#import "GLFirebaseRef.h"

//base map rest url
#define kBaseMapURL @"http://services.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer"
#define kSettingsSegueIdentifier @"SettingsViewSegue"
#define kAccuracyValueKeyPath @"self.parameters.accuracyValue"
#define kFrequencyValueKeyPath @"self.parameters.frequencyValue"

@interface GpsSketchingSampleViewController()

//the map view
@property (nonatomic, strong) IBOutlet AGSMapView *mapView;

//the sketch layer used to draw the gps track
@property (nonatomic, strong) AGSSketchGraphicsLayer *gpsSketchLayer;
@property (nonatomic, strong) AGSGraphicsLayer *otherUserLayer;

@property (nonatomic, strong) IBOutlet UIBarButtonItem *startStopButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *addCurrentLocButton;

@property (nonatomic, strong) Parameters *parameters;

@property (nonatomic, strong)Firebase* myLocationRef;

@property (nonatomic) bool loadingCompleted;
@property (nonatomic, strong) NSMutableDictionary *userIdToGraphicDict;

@property (nonatomic, strong) NSMutableDictionary *geometryDict;

@property (nonatomic, strong) NSString *myID;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *lockButton;

@property (nonatomic) BOOL lock;

//starts the sketching of location updates
- (IBAction)startGPSSketching:(id)sender;

//stops the gps sketching
- (IBAction)stopGPSSketching;

- (IBAction)showCurrentLocation;

//this allows the user to add the the location in between the sketched points as a vertex.
- (IBAction)addCurrentLocationAsVertex;

//stops the CLLocation manager from seding updates
- (void)stopUpdatingLocation;

@end

@implementation GpsSketchingSampleViewController

#pragma mark - UIViewController methods
- (NSString *) myID {
    return @"3";
}

- (NSMutableDictionary *) userIdToGraphicDict {
    if (!_userIdToGraphicDict) {
        _userIdToGraphicDict = [[NSMutableDictionary alloc]init];
    }
    return _userIdToGraphicDict;
}

// in iOS7 this gets called and hides the status bar so the view does not go under the top iPhone status bar
- (BOOL)prefersStatusBarHidden
{
    return NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.lock = NO;
    self.lockButton.title = @"Lock";
    
    NSString *url = [NSString stringWithFormat:@"https://grolo.firebaseio.com/trips/%d/users/%@", self.currentGroupId, self.myID];
    self.myLocationRef = [[Firebase alloc] initWithUrl:url];
    self.geometryDict = [NSMutableDictionary dictionary];
    
    //initialize the map URL and the tiled map layer.
	NSURL *mapUrl = [NSURL URLWithString:kBaseMapURL];
	AGSTiledMapServiceLayer *tiledLyr = [AGSTiledMapServiceLayer tiledMapServiceLayerWithURL:mapUrl];
    
    //Add the tiled map layer to the map view. 
	[self.mapView addMapLayer:tiledLyr withName:@"Tiled Layer"];
    
    //set the layer delegate to self to check when the layers are loaded. Required to start the gps. 
    self.mapView.layerDelegate = self;
    
    //preparing the gps sketch layer. 
    self.gpsSketchLayer = [[AGSSketchGraphicsLayer alloc] initWithGeometry:nil];
    self.otherUserLayer = [[AGSGraphicsLayer alloc] init];
    
	[self.mapView addMapLayer:self.gpsSketchLayer withName:@"Sketch layer"];
    [self.mapView addMapLayer:self.otherUserLayer withName:@"Other Layer"];
    
    //this button is enabled only when the trackin has started. 
    self.addCurrentLocButton.enabled = NO;
    
    self.startStopButton.enabled = NO;
    
    //instantiate the parameters object
    self.parameters = [[Parameters alloc] init];
    
    //observe for changes in the parameters/settings
    [self addObserver:self forKeyPath:kAccuracyValueKeyPath options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:kFrequencyValueKeyPath options:NSKeyValueObservingOptionNew context:nil];
    
    Firebase* users = [[Firebase alloc] initWithUrl: [NSString stringWithFormat:@"https://grolo.firebaseio.com/trips/%d/users", self.currentGroupId]];
    
    __weak GpsSketchingSampleViewController *weakSelf = self;
    [users observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *snapshot) {
        NSLog(@"adding new user");
        NSString *userID = snapshot.name;
        if ([weakSelf.myID isEqualToString:userID]) {
            return;
        }
        
        NSDictionary *user = snapshot.value;
        NSDictionary *userLocation = [user objectForKey:@"location"];
        AGSPoint* point = [[AGSPoint alloc] init];
        [point decodeWithJSON: userLocation];
                
        AGSGeometry *geometry = point;
        AGSSymbol *symbol = [weakSelf.mapView.locationDisplay courseSymbol];
        AGSGraphic *graphic = [AGSGraphic graphicWithGeometry:geometry
                                                       symbol:symbol
                                                   attributes:nil];
        
        [weakSelf.userIdToGraphicDict setValue:graphic forKey:userID];
        [weakSelf.otherUserLayer addGraphic:graphic];
        
        [self.geometryDict setObject:geometry forKey:userID];
    }];
    
    [users observeEventType:FEventTypeChildRemoved withBlock:^(FDataSnapshot *snapshot) {
        NSLog(@"removing user");
        NSString *userID = snapshot.name;
        AGSGraphic *graphic = [weakSelf.userIdToGraphicDict valueForKey:userID];
        [weakSelf.userIdToGraphicDict removeObjectForKey:userID];
        [weakSelf.gpsSketchLayer removeGraphic:graphic];
    }];
    
    [users observeEventType:FEventTypeChildChanged withBlock:^(FDataSnapshot *snapshot) {
        NSString *userID = snapshot.name;
        NSLog(@"@updating user: %@", userID);
        if ([weakSelf.myID isEqualToString:userID]) {
            return;
        }
        
        NSDictionary *user = snapshot.value;
        NSDictionary *userLocation = [user objectForKey:@"location"];
        AGSGraphic *graphic = [weakSelf.userIdToGraphicDict valueForKey:userID];
        AGSPoint *point = (AGSPoint *) graphic.geometry;
        [point decodeWithJSON: userLocation];
        [weakSelf.otherUserLayer removeGraphic:graphic];
        [weakSelf.otherUserLayer addGraphic:graphic];
    }];

}

- (IBAction)lock:(id)sender
{
    self.lock = !self.lock;
    self.lockButton.title = self.lock? @"Unlock" : @"Lock";
}

- (void)zoomToGroup
{
    if (self.lock)
    {
        AGSGeometry *unionGeometry = [[AGSGeometryEngine defaultGeometryEngine] unionGeometries:self.geometryDict.allValues];
        [self.mapView zoomToGeometry:unionGeometry withPadding:100.0f animated:YES];
    }
}

- (AGSCompositeSymbol*)greenSymbolWithNumber:(NSInteger)stopNumber {
	AGSCompositeSymbol *cs = [AGSCompositeSymbol compositeSymbol];
	
    // create outline
	AGSSimpleLineSymbol *sls = [AGSSimpleLineSymbol simpleLineSymbol];
	sls.color = [UIColor blackColor];
	sls.width = 1;
	sls.style = AGSSimpleLineSymbolStyleSolid;
	
    // create main circle
	AGSSimpleMarkerSymbol *sms = [AGSSimpleMarkerSymbol simpleMarkerSymbol];
	sms.color = [UIColor greenColor];
	sms.outline = sls;
	sms.size = CGSizeMake(10, 10);
	sms.style = AGSSimpleMarkerSymbolStyleCircle;
	[cs addSymbol:sms];
	
	return cs;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    //Pass the interface orientation on to the map's gps so that
    //it can re-position the gps symbol appropriately in 
    //compass navigation mode
    self.mapView.locationDisplay.interfaceOrientation = interfaceOrientation;
    return YES;
}


- (void)viewDidUnload {
    //Stop the GPS, undo the map rotation (if any)
    if([self.mapView.locationDisplay isDataSourceStarted]){
        [self.mapView.locationDisplay stopDataSource];
    }
    [self.locationManager stopUpdatingLocation];
    self.locationManager = nil;
    self.mapView = nil;
    self.gpsSketchLayer = nil;
    self.startStopButton = nil;
    self.addCurrentLocButton = nil;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self stopGPSSketching];
}

#pragma mark - 

//update the location manager parameters if the settings are changed during sketching
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:kAccuracyValueKeyPath]) {
        self.locationManager.desiredAccuracy = [self.parameters.accuracyValue doubleValue];
    }
    else if ([keyPath isEqualToString:kFrequencyValueKeyPath]) {
        self.locationManager.distanceFilter = [self.parameters.frequencyValue doubleValue];
    }
}

#pragma mark - AGSMapViewLayerDelegate methods

- (void)mapViewDidLoad:(AGSMapView *) mapView
{      
    [self.mapView.locationDisplay startDataSource];
    self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeDefault;
    
    self.startStopButton.enabled = YES;
    
    //setting the geometry of the gps sketch layer to polyline. 
    self.gpsSketchLayer.geometry = [[AGSMutablePolyline alloc] initWithSpatialReference:self.mapView.spatialReference];
    
    //set the midvertex symbol to nil to avoid the default circle symbol appearing in between vertices
    self.gpsSketchLayer.midVertexSymbol = nil;
    
    [self startGPSSketching:nil];
}

#pragma mark - Action methods

- (IBAction)showCurrentLocation
{
    [self.mapView centerAtPoint:[self.mapView.locationDisplay mapLocation] animated:YES];
    self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeDefault;
}

- (IBAction)addCurrentLocationAsVertex
{
    //add the present gps point to the sketch layer. Notice that we do not have to reproject this point as the mapview's gps object is returing the point in the same spatial reference. 
    //index -1 causes vertex to be added at the end
    [self.gpsSketchLayer insertVertex:[self.mapView.locationDisplay mapLocation] inPart:0 atIndex:-1];
    
}

- (IBAction)startGPSSketching:(id)sender
{        
    //we remove the previos part from the sketch layer as we are going to start a new GPS path. 
    [self.gpsSketchLayer removePartAtIndex:0];
    
    //add a new path to the geometry in preparation of adding vertices to the path
    [self.gpsSketchLayer addPart];
    
    //create the location manager. 
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    
    //set the preferences that was configured using the settings view. 
    self.locationManager.desiredAccuracy = [self.parameters.accuracyValue doubleValue];
    self.locationManager.distanceFilter = [self.parameters.frequencyValue doubleValue];
    
    //start the location maneger. 
    [self.locationManager startUpdatingLocation];
    
    //by enabling this, the user can now add their prest location as a vertex to the path.
    self.addCurrentLocButton.enabled = YES;
   
}

- (IBAction)stopGPSSketching
{
    
    //stop the CLLocation manager from sending updates. 
    [self.locationManager stopUpdatingLocation];  
      
    //change the button title back to Start
    self.startStopButton.title = @"Start";
    
    //disable the button for adding current location as vertex. 
    self.addCurrentLocButton.enabled = NO;
}


#pragma mark Location Manager Interactions

/*
 * We want to get and store a location measurement that meets the desired accuracy. For this example, we are
 *      going to use horizontal accuracy as the deciding factor. In other cases, you may wish to use vertical
 *      accuracy, or both together.
 */
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    
    
    // test that the horizontal accuracy does not indicate an invalid measurement
    if (newLocation.horizontalAccuracy < 0) return;    
    
    //add the present gps point to the sketch layer. Notice that we do not have to reproject this point as the mapview's gps object is returing the point in the same spatial reference. 
    //index -1 forces the vertex to be added at the end
    
//    [self.gpsSketchLayer insertVertex:[self.mapView.locationDisplay mapLocation] inPart:0 atIndex:-1];
    [self.gpsSketchLayer clear];
    
    [self.gpsSketchLayer insertVertex:[self.mapView.locationDisplay mapLocation] inPart:0 atIndex:-1];

//    NSLog(@"%@",[self.mapView.locationDisplay mapLocation]);
    AGSPoint *point = [self.mapView.locationDisplay mapLocation];
    
    [[self.myLocationRef childByAppendingPath:@"location"] setValue:[point encodeToJSON]];
    
    [self.geometryDict setObject:point forKey:self.myID];
    
    [self zoomToGroup];
//    
//    [[self.myLocationRef childByAppendingPath:@"symbol"] setValue:[self.mapView.locationDisplay location]];
//    
//    NSLog(@"%@",[self.mapView.locationDisplay courseSymbol]);
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    // The location "unknown" error simply means the manager is currently unable to get the location.
    if ([error code] != kCLErrorLocationUnknown) {
        [self stopUpdatingLocation];
    }
}

- (void)stopUpdatingLocation {    
    //stop the location manager and set the delegate to nil;
    [self.locationManager stopUpdatingLocation];
    self.locationManager.delegate = nil;
}

#pragma mark - 

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:kSettingsSegueIdentifier]) {
        SettingsViewController *controller = [segue destinationViewController];
        controller.parameters = self.parameters;
        
        if ([[AGSDevice currentDevice] isIPad]) {
            controller.modalPresentationStyle = UIModalPresentationFormSheet;
    
            //present settings view
            controller.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
            controller.view.superview.bounds = CGRectMake(0, 0, 400, 300);
        }
    }
}

@end
