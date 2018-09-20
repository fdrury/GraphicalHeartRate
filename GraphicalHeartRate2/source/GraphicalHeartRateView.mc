using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Graphics as Gfx;
using Toybox.UserProfile as UserProfile;
using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.SensorHistory as SensorHistory;
using Toybox.Time;

/*
Decided to display HR data for entire activity.


If I create a progressive function for what times distances are measured at then I can more
easily remove old data points that are too close together...
Might not even have to store time with heartrate data?

e.g. if time is doubled each time then 2nd data point (index 1) can be erased on each update.

probably function of elapsed time (will need to initiate separately to prevent division by 0)
( elapsed time ) / ( max number of data points )
might need to flex number of data points to allow for linear progression.

tempting to record at a specific rate then periodically cut every other data point and half the rate of recording
*/

//Need to account for HR not being available... Maybe just don't draw data points? (store null)

class GraphicalHeartRateView extends Ui.DataField {
	//MAX_NUMBER_OF_DATA_POINTS should be kept even
	const NUMBER_OF_DATA_POINTS = 60;
	const HR_NOT_SET = 0;
	
	//var hrPeriod = 1000; //starts at 1 second
	var hrHistory = null;
	var currentHR = HR_NOT_SET;
	var backgroundColor;
	var foregroundColor;
	var userProfile = UserProfile.getProfile();
	var heartRateZones = userProfile.getHeartRateZones(userProfile.getCurrentSport());
	var graphPointWidth;
	var session = null;
	var numPoints = 2;
	var dataDuration2 = null;
	var lastFirstHalfSum = 0;
	var lastSecondHalfSum = 0;
    
    // Set the label of the data field here.
    function initialize() {
        DataField.initialize();
        backgroundColor = getBackgroundColor();
        //computes inverse of backgroundColor (black/white)
        foregroundColor = backgroundColor ^ 0xFFFFFF;
    }
    
    function onLayout(dc) {
    	graphPointWidth = (0.0 + dc.getWidth()) / numPoints;
    }

    // The given info object contains all the current workout
    // information. Calculate a value and return it in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info) {
        var dataDuration = new Time.Duration(1800);
        dataDuration2 = 1800;
        if(info.elapsedTime != null){
        	var elapsedTime = (info.elapsedTime / 1000);
	        if(elapsedTime < dataDuration.value() && elapsedTime > 0){
	        	dataDuration = new Time.Duration(elapsedTime);
	        	dataDuration2 = elapsedTime;
	        }
        }
        // See Activity.Info in the documentation for available information.
        if(info.currentHeartRate != null) {
            currentHR = info.currentHeartRate;
        }
        //TODO: fix or remove dataDuration calculations
        //doesn't work due to SDK bug?
        //https://forums.garmin.com/forum/developers/connect-iq/142663-altitude-in-a-watch-face
        //hrHistory = ActivityMonitor.getHeartRateHistory(dataDuration, false);
        hrHistory = ActivityMonitor.getHeartRateHistory(null, false);
    }
    
    function onUpdate(dc) {
        fillUpScreen(dc);
        drawHRzoneDividers(dc);
        dc.setColor( foregroundColor, Gfx.COLOR_TRANSPARENT );
        if(currentHR != null && currentHR != HR_NOT_SET){
        	//constant 35 is just larger than text height to always place it a couple pixels above bottom of data field
        	dc.drawText( dc.getWidth() / 2, dc.getHeight() / 2 - Gfx.getFontHeight(Gfx.FONT_NUMBER_MEDIUM) / 2 - 3, Gfx.FONT_NUMBER_MEDIUM, currentHR, Gfx.TEXT_JUSTIFY_CENTER );
        }
        else if(currentHR == null){
        	dc.drawText( dc.getWidth() / 2, dc.getHeight() / 2 - Gfx.getFontHeight(Gfx.FONT_NUMBER_MEDIUM) / 2 - 3, Gfx.FONT_NUMBER_MEDIUM, "-", Gfx.TEXT_JUSTIFY_CENTER );
        }
        //TODO: draw average line (sloped for first half and second half average?
        //     flat if no data for second half? Or if not entire half hour of data)
        if(hrHistory != null){
        	plotHRData2(dc);
        }
   	}
   	
   	//TEMPORARY for publishing
   	function plotHRData2(dc) {
   		dc.setPenWidth(3);
   		dc.setColor( foregroundColor, Gfx.COLOR_TRANSPARENT );
   		
   		var previousSample = hrHistory.next();
   		var currentSample = hrHistory.next();
   		var elementNumber = 0;
   		//skip elements
   		if(currentSample != null) {
	   		while(Time.now().subtract(previousSample.when).value() > dataDuration2 || previousSample.heartRate == 255 || currentSample.heartRate == 255) {
	   			previousSample = currentSample;
		   		currentSample = hrHistory.next();
	   			if(currentSample == null) {
	   				break;
	   			}
	   		}
   		}
   		if(currentSample != null){
   			elementNumber += 1;
   		}
   		while(currentSample != null) {
   			dc.drawLine(graphPointWidth * (elementNumber - 1), HR2height(previousSample.heartRate, dc),
	   				graphPointWidth * (elementNumber), HR2height(currentSample.heartRate, dc));
   			
   			//skip elements where HR sensor couldn't read
   			do{
	   			previousSample = currentSample;
		   		currentSample = hrHistory.next();
		   		if(currentSample == null){
		   			//prevents type error in loop conditional
		   			break;
		   		}
	   		} while(currentSample.heartRate == 255);
	   		elementNumber += 1;
   		}
   		
   		/*System.println("");
   		System.println("firstHalfSum: " + firstHalfSum);
   		System.println("secondHalfSum: " + secondHalfSum);
   		if(numPoints >= 2){
	   		System.println("firstHalfAvg: " + (firstHalfSum / (numPoints - numPoints / 2)));
	   		System.println("secondHalfAvg: " + (secondHalfSum / (numPoints / 2)));
   		}
   		System.println("numPoints: " + numPoints);
   		System.println("numPoints1: " + (numPoints - numPoints / 2));
   		System.println("numPoints2: " + (numPoints / 2));*/
	   	
	   	/*if(numPoints != elementNumber){
	   		System.println("##############################################");
	   		System.println("##############################################");
	   		System.println("##############################################");
	   	}*/
   		
   		numPoints = elementNumber;
   		if(numPoints < 2){
   			numPoints = 2;
   		}
   		// (numPoints - 1) because one less segment than number of points.
    	graphPointWidth = (0.0 + dc.getWidth()) / (numPoints - 1);
   	}
   	
   	//remove "ACTUAL"
   	function plotHRData2ACTUAL(dc) {
   		var firstHalfSum = 0;
   		var secondHalfSum = 0;
   		var firstHalfCount = 0;
   		var secondHalfCount = 0;
   		
   		dc.setPenWidth(3);
   		dc.setColor( foregroundColor, Gfx.COLOR_TRANSPARENT );
   		
   		var previousSample = hrHistory.next();
   		var currentSample = hrHistory.next();
   		var elementNumber = 0;
   		if(previousSample != null){
   			firstHalfSum = previousSample.heartRate;
   			firstHalfCount += 1;
   		}
   		//skip elements
   		if(currentSample != null) {
	   		while(Time.now().subtract(previousSample.when).value() > dataDuration2 || previousSample.heartRate == 255 || currentSample.heartRate == 255) {
	   			previousSample = currentSample;
		   		currentSample = hrHistory.next();
	   			firstHalfSum = previousSample.heartRate;
	   			if(currentSample == null) {
	   				break;
	   			}
	   		}
   		}
   		if(currentSample != null){
   			elementNumber += 1;
   		}
   		while(currentSample != null) {
   			dc.drawLine(graphPointWidth * (elementNumber), HR2height(previousSample.heartRate, dc),
	   				graphPointWidth * (elementNumber + 1), HR2height(currentSample.heartRate, dc));
	   		
	   		if(elementNumber < numPoints / 2){
	   			firstHalfSum += currentSample.heartRate;
	   			firstHalfCount += 1;
	   		}
	   		else if(elementNumber <= numPoints){
	   			secondHalfSum += currentSample.heartRate;
	   			secondHalfCount += 1;
	   		}
   			
   			//skip elements where HR sensor couldn't read
   			do{
	   			previousSample = currentSample;
		   		currentSample = hrHistory.next();
		   		if(currentSample == null){
		   			//prevents type error in loop conditional
		   			break;
		   		}
	   		} while(currentSample.heartRate == 255);
	   		elementNumber += 1;
   		}
   		
   		//fixes transition between number of points
   		/*if(lastFirstHalfSum != firstHalfSum || lastSecondHalfSum != secondHalfSum){
   			var tempSum = firstHalfSum;
   			firstHalfSum = lastFirstHalfSum;
   			lastFirstHalfSum = tempSum;
   			tempSum = secondHalfSum;
   			secondHalfSum = lastSecondHalfSum;
   			lastSecondHalfSum = tempSum;
   		}*/
   		
   		/*System.println("");
   		System.println("firstHalfSum: " + firstHalfSum);
   		System.println("secondHalfSum: " + secondHalfSum);
   		if(numPoints >= 2){
	   		System.println("firstHalfAvg: " + (firstHalfSum / (numPoints - numPoints / 2)));
	   		System.println("secondHalfAvg: " + (secondHalfSum / (numPoints / 2)));
   		}
   		System.println("numPoints: " + numPoints);
   		System.println("numPoints1: " + (numPoints - numPoints / 2));
   		System.println("numPoints2: " + (numPoints / 2));*/
	   	
	   	//draw the average if sufficiently large screen (e.g. not if only 1/4 size)
	   	//draw numbers too. Maybe always draw lines but only numbers on large screen?
	   	if(numPoints >= 2 && firstHalfCount > 0 && secondHalfCount > 0){
	   		dc.setColor( Gfx.COLOR_PURPLE, Gfx.COLOR_TRANSPARENT );
	   		dc.drawLine(0, HR2height(firstHalfSum / firstHalfCount, dc),
	   				dc.getWidth(), HR2height(secondHalfSum / secondHalfCount, dc));
	   		//This should just exclude VivoActive HR (148)
	   		if(dc.getWidth() > 150){
		   		dc.drawText(5, dc.getHeight() / 2 - 10, Gfx.FONT_SYSTEM_XTINY,
		   				firstHalfSum / firstHalfCount, Gfx.TEXT_JUSTIFY_LEFT);
		   		dc.drawText(dc.getWidth() - 5, dc.getHeight() / 2 - 10, Gfx.FONT_SYSTEM_XTINY,
		   				secondHalfSum / secondHalfCount, Gfx.TEXT_JUSTIFY_RIGHT);
	   		}
	   	}
	   	if(numPoints == 1 && firstHalfSum != 0){
	   		dc.setColor( Gfx.COLOR_PURPLE, Gfx.COLOR_TRANSPARENT );
	   		dc.drawLine(0, HR2height(firstHalfSum, dc),
	   				dc.getWidth(), HR2height(firstHalfSum, dc));
	   		if(dc.getWidth() > 150){
		   		dc.drawText(5, dc.getHeight() / 2 - 10, Gfx.FONT_SYSTEM_XTINY,
		   				firstHalfSum, Gfx.TEXT_JUSTIFY_LEFT);
		   		dc.drawText(dc.getWidth() - 5, dc.getHeight() / 2 - 10, Gfx.FONT_SYSTEM_XTINY,
		   				firstHalfSum, Gfx.TEXT_JUSTIFY_RIGHT);
	   		}
	   	}
	   	
	   	/*if(numPoints != elementNumber){
	   		System.println("##############################################");
	   		System.println("##############################################");
	   		System.println("##############################################");
	   	}*/
   		
   		numPoints = elementNumber;
   		if(numPoints < 2){
   			numPoints = 1;
   		}
    	graphPointWidth = (0.0 + dc.getWidth()) / numPoints;
   	}
   	
   	function fillUpScreen(dc) {
   		//clear screen
   		dc.setColor( backgroundColor, backgroundColor );
        dc.clear();
        
        var reverseHeartRateZones = heartRateZones.reverse();
        var color = 0xFFAA00;
        var colors = new [5];
        colors[0] = Gfx.COLOR_RED;
        colors[1] = Gfx.COLOR_ORANGE;
        colors[2] = Gfx.COLOR_GREEN;
        colors[3] = Gfx.COLOR_BLUE;
        colors[4] = Gfx.COLOR_LT_GRAY;
        //might end up drawing guide lines
        
        
        if(currentHR != null) {
            for(var i = 0; i < reverseHeartRateZones.size() - 1; i += 1) {
            	var zoneHeight = currentHR;
            	dc.setColor(colors[i] , Gfx.COLOR_TRANSPARENT);
            	if(zoneHeight > reverseHeartRateZones[i]) {
            		zoneHeight = reverseHeartRateZones[i];
            	}
            	dc.fillRectangle(0, HR2height(zoneHeight, dc), dc.getWidth(), dc.getHeight() - HR2height(zoneHeight, dc));
            }
        }
   	}
   	
   	function drawHRzoneDividers(dc){
   		//could probably label divisions if I wanted to (I don't think I do want to)
   		dc.setColor(Gfx.COLOR_DK_GRAY , Gfx.COLOR_TRANSPARENT);
   		dc.setPenWidth(1);
   		for(var i = 1; i < heartRateZones.size() - 1; i++){
   			dc.drawLine(0, HR2height(heartRateZones[i], dc), dc.getWidth(), HR2height(heartRateZones[i], dc));
   		}
   		//TODO: add labelled time markings
   	}
   	
   	function HR2height(HR, dc){
   		var maxHeartRate = heartRateZones[heartRateZones.size()-1];
   		var minHeartRate = heartRateZones[0];
   		var heightMultiplier = dc.getHeight().toDouble() / (maxHeartRate - minHeartRate).toDouble();
   		return dc.getHeight() - (HR - minHeartRate) * heightMultiplier;
   	}
}