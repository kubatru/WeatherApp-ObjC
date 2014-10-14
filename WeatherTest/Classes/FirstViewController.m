//
//  FirstViewController.m
//  WeatherTest
//
//  Created by Jakub Truhlar on 09.10.14.
//  Copyright (c) 2014 Jakub Truhlar. All rights reserved.
//

#import "FirstViewController.h"
#import "Macros.h"
#import "Constants.h"
#import "WeatherDictionaryPackageParser.h"
#import "WeatherDictionaryParser.h"

static NSString *globalCityName;
static NSMutableArray *forecastDays;
static NSMutableArray *forecastDescriptions;
static NSMutableArray *forecastAverageCs;
static NSMutableArray *forecastAverageFs;

@interface FirstViewController ()

@end

@implementation FirstViewController

- (void)viewDidAppear:(BOOL)animated
{
    // Get the coordinations
    // We dont have a refresh button so we can refresh content everytime user come here
    [self.locationManager startUpdatingLocation];
}

- (void)viewDidLoad {
    
    // Set NSUserDefaults
    defaults = [NSUserDefaults standardUserDefaults];
    
    // Check if its already exists
    if (!([defaults objectForKey:@"DistanceValue"] || [defaults objectForKey:@"TemperatureValue"])) {
        
        NSString *distanceValue = @"Meters";
        NSString *temperatureValue = @"Celsius";
        
        [defaults setObject:distanceValue forKey:@"DistanceValue"];
        [defaults setObject:temperatureValue forKey:@"TemperatureValue"];
    }
    
    // Change graphics
    [self applyAppearance];
    
    [super viewDidLoad];
    
    // Start the locationManager
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    
    // Check for iOS 8. Without this guard the code will crash with "unknown selector" on iOS 7.
    // Also NSLocationWhenInUseUsageDescription or NSLocationAlwaysUsageDescription must be in plist (authorization by user request)
    if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [self.locationManager requestWhenInUseAuthorization];
    }
    
    // Track the reachability
    [self startReachabilityNotification];
    
    
}

- (void)startReachabilityNotification
{
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        
        switch (status) {
            case AFNetworkReachabilityStatusNotReachable:
                // NSLog(@"No Internet Connection");
                break;
                
            case AFNetworkReachabilityStatusReachableViaWiFi:
                // NSLog(@"WIFI");
            case AFNetworkReachabilityStatusReachableViaWWAN:
                // NSLog(@"Cellular");
                // Get the coordinations
                [self.locationManager startUpdatingLocation];
                break;
                
            default:
                // NSLog(@"Unkown network status");
                break;
        }
    }];
}

- (void)applyAppearance
{
    // programmatically added image for selected state and set the font
    // [UITabBarItem alloc].selectedImage = [UIImage imageNamed:@"TodaySelected"];
    [self.tabBarController.tabBarItem setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIFont fontWithName:@"ProximaNova-Semibold" size:10], NSFontAttributeName, nil] forState:UIControlStateNormal];
    
    // Title in the NavigationBar
    self.title = @"Today";
    
    // Set navigationBar's title font, color and size
    [self.navigationController.navigationBar setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIFont fontWithName:@"ProximaNova-Semibold" size:18],NSFontAttributeName, UIColorWithRGB(333333),NSForegroundColorAttributeName, nil]];
    
    // Remove border + shadow and changing it to the image
    [self.navigationController.navigationBar setBackgroundImage:[[UIImage alloc] init] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [UIImage imageNamed:@"Line"];
}
 
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    // Last object contains the most recent location (lat and lon extends the base URL)
    CLLocation *newLocation = [locations lastObject];
    
    // If the location is more than 10 minutes old, ignore it
    if([newLocation.timestamp timeIntervalSinceNow] > 600)
    {
        return;
    }
    
    // There could be a better code for getting more accurate data (not stop the manager after the first update, but its more battery friendly)
    [self.locationManager stopUpdatingLocation];
    
    // send the location to weather client
    WeatherHTTPClient *client = [WeatherHTTPClient sharedWeatherHTTPClient];
    client.delegate = self;
    [client updateWeatherAtLocation:newLocation forNumberOfDays:5];
    
    // Coordinations back to the name of my city and country
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation: _locationManager.location completionHandler:
     ^(NSArray *placemarks, NSError *error) {
         
         //Get nearby address
         CLPlacemark *placemark = [placemarks objectAtIndex:0];
         
         //String to hold address
         _locationLabel.text = [NSString stringWithFormat:@"%@, %@", placemark.locality, placemark.country];
         
         // Show green arrow
         _greenArrow.hidden = false;
         
         globalCityName = [NSString stringWithFormat:@"%@", placemark.locality];
         
         // Post notification
         [[NSNotificationCenter defaultCenter] postNotificationName:kCoordinatesWereDecodedToCityNameNotification object:nil];
     }];
}

# pragma mark - Global variables

+ (NSString*) globalCityNameString
{
    return globalCityName;
}

+ (NSMutableArray*) forecastDaysArray
{
    return forecastDays;
}

+ (NSMutableArray*) forecastDescriptionsArray
{
    return forecastDescriptions;
}

+ (NSMutableArray*) forecastAverageCArray
{
    return forecastAverageCs;
}

+ (NSMutableArray*) forecastAverageFArray
{
    return forecastAverageFs;
}

#pragma mark - WeatherHTTPClientDelegate

- (void)weatherHTTPClient:(WeatherHTTPClient *)client didUpdateWithWeather:(id)weather
{
    // Got a weather json file? Nice, but we need to acces data elements easily so we call custom methods on NSDictionaries
    self.weather = weather;
    
    if ([[defaults objectForKey:@"TemperatureValue"] isEqualToString:@"Celsius"]) {
        _temperatureLabel.text = [NSString stringWithFormat:@"%@°C", self.weather.currentCondition.tempC];
    }
    
    else {
        _temperatureLabel.text = [NSString stringWithFormat:@"%@°F", self.weather.currentCondition.tempF];
    }
    
    _weatherDescriptionLabel.text = [NSString stringWithFormat:@"%@", self.weather.currentCondition.weatherDescription];
    
    _humidityLabel.text = [NSString stringWithFormat:@"%@%%", self.weather.currentCondition.humidity];
    _precipMMLabel.text = [NSString stringWithFormat:@"%@ mm", self.weather.currentCondition.precipMM];
    _pressureLabel.text = [NSString stringWithFormat:@"%@ hPa", self.weather.currentCondition.pressure];
    
    _windDir16pointLabel.text = [NSString stringWithFormat:@"%@", self.weather.currentCondition.windDir16Point];
    if ([[defaults objectForKey:@"DistanceValue"] isEqualToString:@"Meters"]) {
        _windSpeedLabel.text = [NSString stringWithFormat:@"%@ Km/h", self.weather.currentCondition.windSpeedKmph];
    }
    
    else {
        _windSpeedLabel.text = [NSString stringWithFormat:@"%@ Mph", self.weather.currentCondition.windSpeedMiles];
    }
    
    // Do not forget to select an image for the weather description
    UIImage *image = [UIImage imageNamed:@"Sun_Big"];
    
    if ([self.weather.currentCondition.weatherDescription isEqualToString:@"Cloudy"] || [self.weather.currentCondition.weatherDescription isEqualToString:@"Partly Cloudy"]) {
        image = [UIImage imageNamed:@"Cloudy_Big"];
    }
    
    else if ([self.weather.currentCondition.weatherDescription isEqualToString:@"Windy"] || [self.weather.currentCondition.weatherDescription isEqualToString:@"Partly Windy"]) {
        image = [UIImage imageNamed:@"WInd_Big"];
    }
    
    else if ([self.weather.currentCondition.weatherDescription isEqualToString:@"Lightning"]) {
        image = [UIImage imageNamed:@"Lightning-Big"];
    }
    
    _weatherImage.image = image;
    _weatherImage.frame = CGRectMake(self.weatherImage.frame.origin.x,self.weatherImage.frame.origin.y,image.size.width,image.size.height);
    
    _weatherImage.contentMode = UIViewContentModeScaleAspectFit; // This determines position of image
    _weatherImage.clipsToBounds = YES;
                                                   
    // Update global variables (get array of Dictionaries, with "for" select a Dictionary with index, send data from Dictionary to global mutableArray to right index so it will be accasable by tableView in SecondViewController
    NSArray *upcomingWeather = self.weather.upcomingWeather;
    
    // Alloc NSMutableArrays
    forecastDays = [[NSMutableArray alloc] init];
    forecastDescriptions = [[NSMutableArray alloc] init];
    forecastAverageCs = [[NSMutableArray alloc] init];
    forecastAverageFs = [[NSMutableArray alloc] init];
    
    // Fill the MutableArrays
    for (int i = 0; i < upcomingWeather.count; i++) {
        NSDictionary *forecastDay = upcomingWeather[i];
        forecastDays[i] = [self convertToWeekday:forecastDay.date];
        forecastDescriptions[i] = forecastDay.weatherDescription;
        forecastAverageCs[i] = [self getAverageStringFromNumbers:forecastDay.tempMinC and:forecastDay.tempMaxC]; // No real temp from JSON for the forecast
        forecastAverageFs[i] = [self getAverageStringFromNumbers:forecastDay.tempMinF and:forecastDay.tempMaxF]; // No real temp from JSON for the forecast
    }
}

- (void)weatherHTTPClient:(WeatherHTTPClient *)client didFailWithError:(NSError *)error
{
    // UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error Retrieving Weather" message:[NSString stringWithFormat:@"%@",error] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    // [alertView show];
}

#pragma mark - Share Action

- (IBAction)sendPost:(id)sender {
    
    // Share the current weather
    if (![_locationLabel.text isEqualToString:@"?, ?"]) {
        
        NSArray *activityItems;
        
        if ([[defaults objectForKey:@"TemperatureValue"] isEqualToString:@"Celsius"]) {
            activityItems = @[[NSString stringWithFormat:@"Current condition in %@: %@°C, %@", _locationLabel.text, self.weather.currentCondition.tempC, self.weather.currentCondition.weatherDescription]];
        }
        
        else {
            activityItems = @[[NSString stringWithFormat:@"Current condition in %@: %@°F, %@", _locationLabel.text, self.weather.currentCondition.tempF, self.weather.currentCondition.weatherDescription]];
        }
        
        UIActivityViewController *activityController =[[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
        [self presentViewController:activityController animated:YES completion:nil];
    }
}

#pragma mark - Convertors

- (NSString *)convertToWeekday:(NSString *)date
{
    // Make a formatter to get a weekday
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd";
    NSDate *converted = [formatter dateFromString:date];
    formatter.dateFormat = @"EEEE";
    return [[formatter stringFromDate:converted] capitalizedString];
}

- (NSString *)getAverageStringFromNumbers:(NSNumber *)n1 and:(NSNumber *)n2
{
    int average = ([n1 intValue] + [n2 intValue]) / 2;
    // Round it up
    average = average + 0.5;
    return [NSString stringWithFormat:@"%d", average];
}

@end