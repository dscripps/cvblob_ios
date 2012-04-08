//
//  ViewController.m
//  cvblob_ios
//

#import "ViewController.h"


#include <opencv2/core/core_c.h>
#include <opencv2/opencv.hpp>

#include <cvblob.h>
#include "cvcolor.cpp"
#include "cvlabel.cpp"
#include "cvcontour.cpp"
#include "cvaux.cpp"
#include "cvtrack.cpp"
#include "cvblob.cpp"

@interface ViewController ()

@end

@implementation ViewController

#pragma mark -
#pragma mark OpenCV Support Methods

// NOTE you SHOULD cvReleaseImage() for the return value when end of the code.
- (IplImage *)CreateIplImageFromUIImage:(UIImage *)image {
	CGImageRef imageRef = image.CGImage;
    
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	IplImage *iplimage = cvCreateImage(cvSize(image.size.width, image.size.height), IPL_DEPTH_8U, 4);
	CGContextRef contextRef = CGBitmapContextCreate(iplimage->imageData, iplimage->width, iplimage->height,
													iplimage->depth, iplimage->widthStep,
													colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
	CGContextDrawImage(contextRef, CGRectMake(0, 0, image.size.width, image.size.height), imageRef);
	CGContextRelease(contextRef);
	CGColorSpaceRelease(colorSpace);
    
	IplImage *ret = cvCreateImage(cvGetSize(iplimage), IPL_DEPTH_8U, 3);
	cvCvtColor(iplimage, ret, CV_RGBA2BGR);
	cvReleaseImage(&iplimage);
    
	return ret;
}

// NOTE You should convert color mode as RGB before passing to this function
- (UIImage *)UIImageFromIplImage:(IplImage *)image {
	NSLog(@"IplImage (%d, %d) %d bits by %d channels, %d bytes/row %s", image->width, image->height, image->depth, image->nChannels, image->widthStep, image->channelSeq);
    
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	NSData *data = [NSData dataWithBytes:image->imageData length:image->imageSize];
	CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
	CGImageRef imageRef = CGImageCreate(image->width, image->height,
										image->depth, image->depth * image->nChannels, image->widthStep,
										colorSpace, kCGImageAlphaNone|kCGBitmapByteOrderDefault,
										provider, NULL, false, kCGRenderingIntentDefault);
	UIImage *ret = [UIImage imageWithCGImage:imageRef];
	CGImageRelease(imageRef);
	CGDataProviderRelease(provider);
	CGColorSpaceRelease(colorSpace);
	return ret;
}


- (void)blobDetect {
    
	if(imageView.image) {
        
        
        
		IplImage *img = [self CreateIplImageFromUIImage:imageView.image];
        
        cvSetImageROI(img, cvRect(100, 100, 800, 500));
        
        IplImage *grey = cvCreateImage(cvGetSize(img), IPL_DEPTH_8U, 1);
        cvCvtColor(img, grey, CV_BGR2GRAY);
        cvThreshold(grey, grey, 100, 255, CV_THRESH_BINARY);
        
        IplImage *labelImg = cvCreateImage(cvGetSize(grey),IPL_DEPTH_LABEL,1);
        
        cvb::CvBlobs blobs;
        cvLabel(grey, labelImg, blobs);
        
        IplImage *imgOut = cvCreateImage(cvGetSize(img), IPL_DEPTH_8U, 3); cvZero(imgOut);
        cvRenderBlobs(labelImg, blobs, img, imgOut);
        
        // Render contours:
        for (cvb::CvBlobs::const_iterator it=blobs.begin(); it!=blobs.end(); ++it)
        {
            //cvRenderBlob(labelImg, (*it).second, img, imgOut);
            
            CvScalar meanColor = cvBlobMeanColor((*it).second, labelImg, img);
            cout << "Mean color: r=" << (unsigned int)meanColor.val[0] << ", g=" << (unsigned int)meanColor.val[1] << ", b=" << (unsigned int)meanColor.val[2] << endl;
            cvb::CvContourPolygon *polygon = cvConvertChainCodesToPolygon(&(*it).second->contour);
            
            cvb::CvContourPolygon *sPolygon = cvb::cvSimplifyPolygon(polygon, 10.);
            cvb::CvContourPolygon *cPolygon = cvb::cvPolygonContourConvexHull(sPolygon);
            
            cvRenderContourChainCode(&(*it).second->contour, imgOut);
            cvb::cvRenderContourPolygon(sPolygon, imgOut, CV_RGB(0, 0, 255));
            cvb::cvRenderContourPolygon(cPolygon, imgOut, CV_RGB(0, 255, 0));
            
            delete cPolygon;
            delete sPolygon;
            delete polygon;
            
            // Render internal contours:
            for (cvb::CvContoursChainCode::const_iterator jt=(*it).second->internalContours.begin(); jt!=(*it).second->internalContours.end(); ++jt)
                cvb::cvRenderContourChainCode((*jt), imgOut);
        }
		imageView.image = [self UIImageFromIplImage:imgOut];
        
	}
}



- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    NSString *path = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"png"];
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    
    imageView = [[UIImageView alloc] initWithImage:image];
    [self blobDetect];
    [self.view addSubview:imageView];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

@end
