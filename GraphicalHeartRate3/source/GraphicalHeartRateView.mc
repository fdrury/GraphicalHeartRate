using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Graphics as Gfx;
using Toybox.UserProfile as UserProfile;

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
	const MAX_NUMBER_OF_DATA_POINTS = 60;
	const HR_NOT_SET = 0;
	
	var timeBetweenUpdates = 1000; //starts at 1 second
	var currentHR = HR_NOT_SET;
	var backgroundColor;
	var foregroundColor;
	//initialization ensures that initial HR is recorded
	var timeOfLastRecording = -timeBetweenUpdates;
	var historyHR = new [0];
	var userProfile = UserProfile.getProfile();
	var heartRateZones = userProfile.getHeartRateZones(userProfile.getCurrentSport());
    
    // Set the label of the data field here.
    function initialize() {
        DataField.initialize();
        backgroundColor = getBackgroundColor();
        //computes inverse of backgroundColor (black/white)
        foregroundColor = backgroundColor ^ 0xFFFFFF;
    }

    // The given info object contains all the current workout
    // information. Calculate a value and return it in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info) {
        // See Activity.Info in the documentation for available information.
        if(info.currentHeartRate != null) {
            currentHR = info.currentHeartRate;
        }
        
        if(info.elapsedTime != null) {
        	//TODO: use timer instead ( this might also help with seeing HR before activity starts? - if timer set up in initialize() )
        	//maybe? maybe not?
        	if(info.elapsedTime - timeOfLastRecording > timeBetweenUpdates) {
        		if(info.currentHeartRate != null) {
        			//halves the array so that all data is kept (just keep even data points)
        			//also average out values when deleting
        			//TODO: check for off-by-one errors
        			//TODO: at some point change 64s to 60s etc. for even data increments (easier to label/read)
        			//maybe stop splitting once looking at an hour of data
        			if(historyHR.size() >= MAX_NUMBER_OF_DATA_POINTS) {
        				for(var i = 0; i < historyHR.size()/2; i+=1){
        					historyHR[i] = (historyHR[i*2] + historyHR[i*2+1]) / 2;
        				}
        				historyHR = historyHR.slice(0, historyHR.size()/2);
        				timeBetweenUpdates *= 2;
        			}
        			historyHR.add(info.currentHeartRate);
        			timeOfLastRecording = info.elapsedTime;
        		}
        	}
        }
    }
    
    function onUpdate(dc) {
        fillUpScreen(dc);
        drawHRzoneDividers(dc);
        dc.setColor( foregroundColor, Gfx.COLOR_TRANSPARENT );
        plotHRData(dc);
        if(historyHR.size() >= 2){
        	plotAverage(dc);
        }
        if(currentHR != null && currentHR != HR_NOT_SET){
        	//constant 35 is just larger than text height to always place it a couple pixels above bottom of data field
        	dc.drawText( dc.getWidth() / 2, dc.getHeight() / 2 - 20, Gfx.FONT_NUMBER_MEDIUM, currentHR, Gfx.TEXT_JUSTIFY_CENTER );
        }
        else if(currentHR == null){
        	dc.drawText( dc.getWidth() / 2, dc.getHeight() - 35, Gfx.FONT_LARGE, "-", Gfx.TEXT_JUSTIFY_CENTER );
        }
   	}
   	
   	function plotHRData(dc) {
   		var graphPointWidth = dc.getWidth();
   		if(historyHR.size() > 1) {
   			//don't do integer division
   			graphPointWidth = (0.0 + dc.getWidth()) / historyHR.size();
   		}
   		dc.setPenWidth(3);
   		dc.setColor( foregroundColor, Gfx.COLOR_TRANSPARENT );
   		for(var i = 1; i < historyHR.size(); i+=1) {
	   		dc.drawLine(graphPointWidth * (i-1), HR2height(historyHR[i-1], dc),
	   				graphPointWidth * i,HR2height(historyHR[i], dc));
	   	}
	   	if(historyHR.size() >= 1 && currentHR != null){
	   		dc.drawLine(graphPointWidth * (historyHR.size()-1), HR2height(historyHR[historyHR.size()-1], dc),
	   				dc.getWidth(), HR2height(currentHR, dc));
	   	}
	   	else if(currentHR != null) {
	   		dc.drawLine(graphPointWidth * (historyHR.size()-1), HR2height(currentHR, dc),
	   				graphPointWidth * historyHR.size(), HR2height(currentHR, dc));
	   	}
   	}
   	
   	function plotAverage(dc){
   		dc.setPenWidth(2);
   		dc.setColor( Gfx.COLOR_PURPLE, Gfx.COLOR_TRANSPARENT );
   		
   		var firstHalfAvg = 0;
   		var secondHalfAvg = 0;
   		for(var i = 1; i < historyHR.size(); i+=1) {
   			if(i < historyHR.size() / 2) {
   				firstHalfAvg += historyHR[i];
   			}
   			else {
   				secondHalfAverage += historyHR[i];
   			}
   		}
   		firstHalfAvg /= historyHR.size() / 2;
   		secondHalfAvg /= historyHR.size() - historyHR.size() / 2;
   		
   		dc.drawLine(0, HR2height(firstHalfAvg, dc), dc.getWidth(), HR2height(secondHalfAvg, dc));
   		if(dc.getWidth() > 150){
	   		dc.drawText(5, dc.getHeight() / 2 - 10, Gfx.FONT_SYSTEM_XTINY,
	   				firstHalfAvg, Gfx.TEXT_JUSTIFY_LEFT);
	   		dc.drawText(dc.getWidth() - 5, dc.getHeight() / 2 - 10, Gfx.FONT_SYSTEM_XTINY,
	   				secondHalfAverage, Gfx.TEXT_JUSTIFY_RIGHT);
   		}
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
   		for(var i = 1; i < heartRateZones.size(); i++){
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