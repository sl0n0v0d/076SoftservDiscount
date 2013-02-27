//
//  MapViewController.m
//  ImageAnnotation
//
//  Created by Mykola on 1/14/13.
//  Copyright (c) 2013 Mykola. All rights reserved.
//

#import "MapViewController.h"
#import "Annotation.h"
#import "DiscountObject.h"
#import "Category.h"
#import "CustomPicker.h"
#import "DetailsViewController.h"
#import "IconConverter.h"

#define MAP_SPAN_DELTA 0.005


@interface MapViewController ()<MKAnnotation,MKMapViewDelegate>

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (nonatomic) CustomCalloutView *calloutView;
@property (nonatomic) NSMutableArray *annArray;
@property (nonatomic) NSArray *dataSource; 
@property (nonatomic) NSArray *categoryObjects;
@property (nonatomic) UIButton *filterButton;
@property (nonatomic,assign) NSInteger selectedIndex;
@property (nonatomic,assign) DiscountObject *selectedObject;

@end

@implementation MapViewController

@synthesize calloutView, annArray;
@synthesize location;
@synthesize managedObjectContext;
@synthesize dataSource;
@synthesize categoryObjects;
@synthesize selectedIndex;
@synthesize filterButton;
@synthesize selectedObject;

#pragma mark - View

- (void)viewDidLoad
{
    
    [super viewDidLoad];
    
    [self setControllerButtons];
    self.mapView.delegate = self;
    self.dataSource = [self fillPicker];
    self.annArray = [[NSMutableArray alloc] init];
    
    
    self.calloutView.delegate = self;
    self.calloutView = [CustomCalloutView new];
    
    // button for callout
    UIImage *image = [UIImage   imageNamed:@"annDetailButton.png"];
    UIButton *disclosureButton = [UIButton buttonWithType:UIButtonTypeCustom];
    CGRect frame = CGRectMake(0.0, 0.0, 32 ,32);
    disclosureButton.frame = frame;
    [disclosureButton setBackgroundImage:image forState:UIControlStateNormal];
    disclosureButton.backgroundColor = [UIColor clearColor];
    [disclosureButton addTarget:self action:@selector(disclosureTapped) forControlEvents:UIControlEventTouchUpInside];
    
    self.calloutView.rightAccessoryView = disclosureButton;
    
    self.annArray = [NSArray arrayWithArray: [self getAllPins]];
    
    
    [self gotoLocation];
}

- (void)viewWillAppear:(BOOL)animated
{
    
    [super viewDidAppear:animated];
    
    [self gotoLocation];
    
    [self.mapView removeAnnotations:self.mapView.annotations];  
    [self.navigationController.navigationBar addSubview:filterButton];
    [self.mapView addAnnotations:self.annArray];
}


-(void)setControllerButtons
{
    //filterButton
    UIImage *filterButtonImage = [UIImage imageNamed:@"filterButton.png"];
    filterButton = [UIButton buttonWithType:UIButtonTypeCustom];
    CGRect filterFrame = CGRectMake(self.navigationController.navigationBar.frame.size.width - filterButtonImage.size.width-5 , self.navigationController.navigationBar.frame.size.height- filterButtonImage.size.height-8, filterButtonImage.size.width,filterButtonImage.size.height);
    filterButton.frame = filterFrame;
    
    [filterButton setBackgroundImage:filterButtonImage forState:UIControlStateNormal];
    [filterButton addTarget:self action:@selector(filterCategory:) forControlEvents:UIControlEventTouchUpInside];
    filterButton.backgroundColor = [UIColor clearColor];
        
    //geoButton
    UIImage *geoButtonImage = [UIImage imageNamed:@"geoButton.png"];
    UIButton *geoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    CGRect geoFrame = CGRectMake(5, self.mapView.frame.size.height-self.navigationController.navigationBar.frame.size.height- geoButtonImage.size.height-5, geoButtonImage.size.width,geoButtonImage.size.height);
    geoButton.frame = geoFrame;
    
    [geoButton setBackgroundImage:geoButtonImage forState:UIControlStateNormal];
    [geoButton addTarget:self action:@selector(getLocation:) forControlEvents:UIControlEventTouchUpInside];
    geoButton.backgroundColor = [UIColor clearColor];
    [self.mapView addSubview:geoButton];
}

#pragma mark - createAnnotation

- (Annotation*)createAnnotationFromData:(DiscountObject*)discountObject
{
    CLLocationCoordinate2D tmpCoord;
    
    // annotation for pins
    Annotation *myAnnotation;
    myAnnotation= [[Annotation alloc]init];
    
    // font for pins image
    UIFont *font = [UIFont fontWithName:@"icons" size:10];
    // image with text
    UIImage *emptyImage =[UIImage imageNamed:@"emptyLeftImage.png"];
    UIImage *emptyPinImage = [UIImage imageNamed:@"emptyPin.png"];
    
    NSNumber *dbLongitude = discountObject.geoLongitude;
    NSNumber *dbLatitude = discountObject.geoLatitude;
    NSString *dbTitle = discountObject.name;
    NSString *dbSubtitle = discountObject.address;
    NSSet *dbCategories = discountObject.categories;
    NSNumber *dbDiscountTo = discountObject.discountTo;
    Category *dbCategory = [dbCategories anyObject];
    

    // formating discountValue to "x%", where x discountValue
    NSString *value = [dbDiscountTo stringValue];
    NSString *discTo = value;
    
    discTo = [discTo  stringByAppendingString:@"%"];
    
    // creating new image
    UIImage *myNewImage = [self setText:discTo
                               withFont: nil
                               andColor:[UIColor blackColor]
                                onImage:emptyImage];
    UIImage *pinImage = [self setText:dbCategory.fontSymbol withFont:font
                             andColor:[UIColor whiteColor] onImage:emptyPinImage];
    
    
    myAnnotation= [[Annotation alloc]init];
    
    tmpCoord.latitude = [dbLatitude doubleValue];
    tmpCoord.longitude =[dbLongitude doubleValue];
    myAnnotation.coordinate = tmpCoord;
    myAnnotation.object = discountObject;
    myAnnotation.title = dbTitle;
    myAnnotation.subtitle = dbSubtitle;
    myAnnotation.pintype = pinImage;
    myAnnotation.leftImage = [[UIImageView alloc] initWithImage: myNewImage];
    return myAnnotation;
}


#pragma mark - Picker section

- (NSArray*)getAllPins
{
    NSMutableArray *tmpArray = [[NSMutableArray alloc]init];
    // fetch objects from db
    NSPredicate *objectsFind = [NSPredicate predicateWithFormat:nil];
    NSFetchRequest *fetch=[[NSFetchRequest alloc] init];
    [fetch setEntity:[NSEntityDescription entityForName:@"Category"
                                 inManagedObjectContext:managedObjectContext]];
    [fetch setPredicate:objectsFind];
    NSArray *objectsFound = [managedObjectContext executeFetchRequest:fetch error:nil];
    
    Annotation *currentAnn = [[Annotation alloc]init];
    for (Category *object1 in objectsFound)
    {
        NSSet *dbAllObjInCategory= object1.discountobject;
        for(DiscountObject *object in dbAllObjInCategory)
        {
            currentAnn = [self createAnnotationFromData:object];
            [tmpArray addObject:currentAnn];
        }
    }
    return tmpArray;
}

- (NSArray*)getPinsByCategory:(int)filterNumber
{
    // fetch objects from db
    NSMutableArray *tmpArray = [[NSMutableArray alloc]init];
    Category *selectedCategory = [self.categoryObjects objectAtIndex:filterNumber];
    NSSet *dbAllObjInSelCategory = selectedCategory.discountobject;
    
    Annotation *currentAnn;
    for(DiscountObject *object in dbAllObjInSelCategory)
    {
        currentAnn = [self createAnnotationFromData:object];
        [tmpArray addObject:currentAnn];
    }
    return  tmpArray;
}

- (NSArray*)fillPicker
{

    NSFetchRequest *fetch = [[NSFetchRequest alloc] init];
    [fetch setEntity:[NSEntityDescription entityForName:@"Category"
                              inManagedObjectContext:managedObjectContext]];
    categoryObjects = [managedObjectContext executeFetchRequest:fetch error:nil];
    NSMutableArray *fetchArr = [[NSMutableArray alloc]init];

    [fetchArr addObject:@"Усі категорії"];
    for ( Category *object in categoryObjects)
    {

        [fetchArr addObject:(NSString*)object.name];
    }
    return [NSArray arrayWithArray:fetchArr];
}


- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)thePickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)thePickerView
numberOfRowsInComponent:(NSInteger)component
{
    return dataSource.count;
}

- (NSString *)pickerView:(UIPickerView *)thePickerView
             titleForRow:(NSInteger)row
            forComponent:(NSInteger)component
{
    return [dataSource objectAtIndex:row];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return toInterfaceOrientation!= UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - TextOnImage

- (UIImage *)setText:(NSString*)text withFont:(UIFont*)font andColor:(UIColor*)color onImage:(UIImage*)startImage
{
    
    NSString *tmpText = @"";
    CGRect rect = CGRectZero;
    
    double margin = 3.0;
    float fontsize = (startImage.size.width - 2 * margin);
    
    if([font isKindOfClass:[UIFont class]])
    {
        // size of custom text in image
        fontsize = fontsize/3;
        font = [font fontWithSize:fontsize];
        tmpText = [IconConverter ConvertIconText:text];
        
        // own const for pin text (height position)
        float ownHeight = 0.4*startImage.size.height;
        
        rect = CGRectMake((startImage.size.width - font.pointSize)/2, ownHeight - font.pointSize/2, startImage.size.width, startImage.size.height);
    }
    else
    {
        fontsize = 10;
        font = [UIFont systemFontOfSize:fontsize];
        
        margin = (startImage.size.width - font.pointSize * text.length/2)/2;
        rect = CGRectMake(margin, (startImage.size.height - font.pointSize)/2, startImage.size.width, startImage.size.height);
        tmpText = text;
        
    }
    
    //work with image
    UIGraphicsBeginImageContextWithOptions(startImage.size,NO, 0.0);
    
    [startImage drawInRect:CGRectMake(0,0,startImage.size.width,startImage.size.height)];
    [color set];
    
    //draw text on image and save result
    [tmpText drawInRect:CGRectIntegral(rect) withFont:font];
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return resultImage;
}


#pragma mark - MKMapViewPin

- (MKAnnotationView *)mapView:(MKMapView *)theMapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    
    
    if ([annotation isKindOfClass:[MKUserLocation class]])
        return nil;
    
    
    if ([annotation isKindOfClass:[Annotation class]])  
    {
        // type cast for property use
        Annotation *newAnnotation;
        newAnnotation = (Annotation *)annotation;
        
        static NSString *stringAnnotationIdentifier = @"StringAnnotationIdentifier";
        
        CustomAnnotationView *annotationView = (CustomAnnotationView *)
        [_mapView dequeueReusableAnnotationViewWithIdentifier:stringAnnotationIdentifier];
        if (!annotationView) {
            annotationView = [[CustomAnnotationView alloc] initWithAnnotation:annotation
                                                              reuseIdentifier:stringAnnotationIdentifier];
        }
        //setting pin image
        annotationView.image = newAnnotation.pintype;
        return annotationView;
    }
    
    return nil;
}




- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

}



#pragma mark - MKMapView

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
    
    if (calloutView.window)
        [calloutView dismissCalloutAnimated];
    Annotation *selectedAnnotation = [self.mapView.selectedAnnotations objectAtIndex:0];
    [self.mapView setCenterCoordinate:selectedAnnotation.coordinate animated:YES];
    [self performSelector:@selector(popupMapCalloutView:) withObject:view afterDelay:0.5];
}

- (void)mapView:(MKMapView *)mapView didDeselectAnnotationView:(MKAnnotationView *)view {

    [calloutView performSelector:@selector(dismissCalloutAnimated) withObject:nil afterDelay:0];
}

#pragma mark - custom callout

- (void)popupMapCalloutView:(CustomAnnotationView *)annotationView {
    if(![[self.mapView.selectedAnnotations objectAtIndex:0]isKindOfClass:[MKUserLocation class]])
    {
        NSArray *selectedAnnotations = self.mapView.selectedAnnotations;
        Annotation *selectedAnnotation = selectedAnnotations.count > 0 ? [selectedAnnotations objectAtIndex:0] : nil;
        
        calloutView.title = selectedAnnotation.title;
        calloutView.subtitle = selectedAnnotation.subtitle;

        calloutView.leftAccessoryView = selectedAnnotation.leftImage;
        self.selectedObject = selectedAnnotation.object;

        ((CustomAnnotationView *)annotationView).calloutView = calloutView;
        [calloutView presentCalloutFromRect:annotationView.bounds
                                     inView:annotationView
                          constrainedToView:self.mapView];
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    [filterButton removeFromSuperview];
    DetailsViewController *dvc = [segue destinationViewController];
    dvc.discountObject = self.selectedObject;
;
    dvc.managedObjectContext = self.managedObjectContext;
    

    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@" "
                                                                             style:UIBarButtonItemStyleBordered
                                                                            target:nil
                                                                            action:nil] ;
    
}

- (void)disclosureTapped {
    [self performSegueWithIdentifier:@"detailsMap" sender:self];
}


- (void)dismissCallout {
    [calloutView dismissCalloutAnimated];
}



#pragma mark - location


- (void)gotoLocation
{
    MKCoordinateRegion newRegion;
    newRegion.center.latitude = 49.836744;
    newRegion.center.longitude = 24.031359;
    newRegion.span.latitudeDelta = MAP_SPAN_DELTA;
    newRegion.span.longitudeDelta = MAP_SPAN_DELTA;
    
    [self.mapView setRegion:newRegion animated:YES];
}

- (IBAction) getLocation:(id)sender {
    
    if(self.mapView.showsUserLocation)
    {
        self.mapView.showsUserLocation = FALSE;
        [location stopUpdatingLocation];
    }
    else
    {
        self.mapView.showsUserLocation = TRUE;
        
        self.location = [[CLLocationManager alloc]init];
        location.delegate = self;
        
        location.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
        location.distanceFilter = kCLDistanceFilterNone;
        [location startUpdatingLocation];
        
    }
}


- (void)mapView:(MKMapView *)aMapView didUpdateUserLocation:(MKUserLocation *)aUserLocation {
    MKCoordinateRegion region;
    MKCoordinateSpan span;
    span.latitudeDelta = MAP_SPAN_DELTA;
    span.longitudeDelta = MAP_SPAN_DELTA;
    
    CLLocationCoordinate2D userCoords;
    userCoords.latitude = aUserLocation.coordinate.latitude;
    userCoords.longitude = aUserLocation.coordinate.longitude;
    
    region.span = span;
    region.center = userCoords;
    [aMapView setRegion:region animated:YES];
}

#pragma mark - filter 

- (IBAction)filterCategory:(UIControl *)sender {
    [CustomPicker showPickerWithRows:self.dataSource initialSelection:self.selectedIndex target:self successAction:@selector(categoryWasSelected:element:)];
    
}


- (void)categoryWasSelected:(NSNumber *)selectIndex element:(id)element {
    
    if(selectedIndex != [selectIndex integerValue])
    {
        self.selectedIndex = [selectIndex integerValue];
        [self.mapView removeAnnotations:self.mapView.annotations];
        
        if (self.selectedIndex<1)
            self.annArray = [NSArray arrayWithArray: [self getAllPins]];
        else
            self.annArray = [NSArray arrayWithArray: [self getPinsByCategory:self.selectedIndex-1]];
        
        [self.mapView addAnnotations:self.annArray];

    }
}





@end
