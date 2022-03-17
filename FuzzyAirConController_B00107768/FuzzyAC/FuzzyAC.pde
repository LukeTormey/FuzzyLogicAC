// Aircon Simulator
// Written by Stephen Sheridan TU Dublin (Blanchardstown Campus) 2021
import processing.core.*;
import com.fuzzylite.*;
import com.fuzzylite.defuzzifier.*;
import com.fuzzylite.activation.*;
import com.fuzzylite.norm.s.*;
import com.fuzzylite.norm.t.*;
import com.fuzzylite.rule.*;
import com.fuzzylite.term.*;
import com.fuzzylite.variable.*;
import controlP5.*;

// Constants
// Initial temperature starting point
final int INITIAL_TEMP = 18;

// Globals vars
// Current room temperature
float roomTemp;
float targetTemp;

// AC action (-/+)
float acCommand;

// Step vars to control perlin noise
float t1 = 3.0;

// Fuzzy Logic objects
Engine engine;
InputVariable inputVariable1;
InputVariable inputVariable2;
OutputVariable outputVariable;
RuleBlock ruleBlock;
  
// GUI Components
ControlP5 cp5;
TargetTempListener targetTempListener;
CheckboxListener acPowerListener;
Chart tempChart;

// Setup some colours
int blue = color(0,174,253);
int red = color(255,0,0);
int black = color(0,0,0);
int grey = color(240,240,240);
int white = color(255,255,255);
int green = color(0,204,102);

public class TargetTempListener implements ControlListener {
    private int targetTemp;
    TargetTempListener(){this.targetTemp = 18;}
    public void controlEvent(ControlEvent theEvent) {
        targetTemp = (int)theEvent.getController().getValue();
    }
    public int getTargetTemp(){return targetTemp;}
}

// Listener class to handle events on the checkbox control
public class CheckboxListener implements ControlListener {
    private int active;
    CheckboxListener(){this.active = 0;}
    public void controlEvent(ControlEvent theEvent) {
        active = (int)theEvent.getController().getValue();
    }
    public boolean isActive(){return active == 1;}
}
void setup() {
    size(800, 360);
  
    // Set the fuzzy logic engine including inputs, outputs and rules
    createFuzzyEngine(); 
    
    // Create a ControlP5 object for the user interface
    cp5 = new ControlP5(this);
    
    // Create the target temperature dial
    cp5.addKnob("Target Temperature")
          .setRange(5,35) // Most room thermostats have this range - don't change
          .setValue(INITIAL_TEMP)
          .setPosition(180,180)
          .setRadius(65)
          .setColorCaptionLabel(black)
          .setDragDirection(Knob.VERTICAL)
          ;
    
    // Create a new listener for the target temperature slider
    targetTempListener = new TargetTempListener();
    // Add a listener so we can receive slider events  
    cp5.getController("Target Temperature").addListener(targetTempListener);
    
    cp5.addCheckBox("AC Checkbox")
          .setPosition(210, 150)
          .setColorForeground(color(0))
          .setColorActive(blue)
          .setColorLabel(color(0))
          .setSize(20, 20)
          .addItem("AC On/Off", 0)
          ;
    acPowerListener = new CheckboxListener();
    // Add a listener so we can receive slider events  
    cp5.getController("AC On/Off").addListener(acPowerListener);
    
    tempChart = cp5.addChart("Temperature")
                 .setPosition(350, 160)
                 .setColorCaptionLabel(black)
                 .setSize(400, 150)
                 .setRange(-15, 45)
                 .setColorBackground(grey)
                 .setLabelVisible(true)
                 .setView(Chart.LINE) // use Chart.LINE, Chart.PIE, Chart.AREA, Chart.BAR_CENTERED
                 ;
    // Setup the dataset for outside temperature
    tempChart.addDataSet("Outside");
    tempChart.setData("Outside", new float[2000]);
    // Setup the dataset for room temperature
    tempChart.addDataSet("Room");
    tempChart.setData("Room", new float[2000]);
    tempChart.setColors("Room", red);
    // Setup the dataset for target temperature
    tempChart.addDataSet("Target");
    tempChart.setData("Target", new float[2000]);
    tempChart.setColors("Target", green);
}

private void drawThermometer(){
    // Draw the thermometer
    stroke(0);
    line(100,300,100,150); // Left side
    line(105,300,105,150); // Right side
    line(100,300,105,300); // Bottom
    fill(red);
    ellipse(103,310,19,19);

    // Draw the tick marks and labels
    fill(black);
    line(90, 300, 100, 300); // Zero tick
    text("0",80,305);
    line(95, (int)(300-18.75), 100, (int)(300-18.75)); // 5 tick
    line(90, (int)(300-37.5), 100, (int)(300-37.5)); // 10 tick
    text("10",73,(int)(300-37.5+5));
    line(95,(int)(300-56.25), 100, (int)(300-56.25)); // 15 tick
    
    line(90, 300-75, 100, 300-75); // 20 tick
    line(95, (int)(300-93.75), 100, (int)(300-93.75)); // 25 tick
    text("20",73,(int)(300-75+5));
    line(90, (int)(300-112.5), 100, (int)(300-112.5)); // 30 tick
    line(95, (int)(300-131.25), 100, (int)(300-131.25)); // 35 tick
    text("30",73,(int)(300-112.5+5));
    line(90, 300-150, 100, 300-150); // 40 tick
    text("40",73,(int)(300-150+5));
}

private void drawTempLevel(float lev){
    // No outline for the water
    noStroke();
    // Set the fill color
    fill(red);
    // Draw the rect for the temp level
    double ratio = 150*(lev / 40); 
    rect(101,(int)(300-ratio),4,(int)(ratio+1));
}
private void drawInfo(float ot, float rt, float tt, float ac){
    // Output the room temp and target temp
    fill(black);
    text("Outside Temp: " + ot,50,35);
    text("Room Temp: " + rt,50,50);
    text("Target Temp: " + tt,50,65);
    text("AC Command: " + ac,50,80);
      
    // Chart legend
    fill(blue);
    rect(350,145, 10,10);
    fill(black);
    text("Outside", 365, 155);
    // Chart legend
    fill(red);
    rect(420,145, 10,10);
    fill(black);
    text("Room", 435, 155);
    // Chart legend
    fill(green);
    rect(480,145, 10,10);
    fill(black);
    text("Target", 495, 155);
}

// Run the system
public void drawSystem(){
    // Clear the background
    background(255);
  
    // Draw all the static visual components
    drawThermometer();
      
    // Constant change
    float outsideTemp = noise(t1);
    // Map the demand to a value between -1 and 1.5
    outsideTemp = map(outsideTemp,0f,1f,-10.0f,40f);
    // Calculate the difference between the outside temp and room temp
    // We will use a scaling factor to make the change in temp gradual
    float tempDelta = (roomTemp - outsideTemp) * 0.001f;
  
    // Get the target temperature
    targetTemp = targetTempListener.getTargetTemp();
  
    // Run the fuzzy engine with inputs and get controller output
    if (acPowerListener.isActive()){
    
      // Run the fuzzy controller on our inputs and get an output
      acCommand = fuzzyACEvaluate(roomTemp, targetTemp);
    
      // Apply the pump action to the current level
      // new roomTemp will be affected by the delta (room - outside) and the AC fuzzy output
      roomTemp = (roomTemp  - tempDelta + (acCommand * 0.01f));
    }
    else if (!acPowerListener.isActive()){
      // If the AC is not active then the room temp will
      // only be affected the outside temp
      roomTemp = roomTemp  - tempDelta;
    }
  
    // Update the temperature level on screen
    drawTempLevel(roomTemp);
        
    // Draw the instrumentation panel
    drawInfo(outsideTemp, roomTemp, targetTemp, acCommand);
    
    // Increment time step for Perlin noise
    t1 += 0.001;
    
    // Push the data from this time step on to the live graph
    tempChart.push("Outside", outsideTemp);
    tempChart.push("Room", roomTemp);
    tempChart.push("Target", targetTemp);
}

// Fuzzy Logic related code
public void createFuzzyEngine(){
    // Create the engine
        engine = new Engine();
        engine.setName("FuzzyAC");

        inputVariable1 = new InputVariable();
        inputVariable1.setEnabled(true);
        inputVariable1.setName("roomTemp");
        // TODO
        // Set the range and terms for the room temperature input
        inputVariable1.addTerm(new Trapezoid("TC", 0, 1, 4, 7));
        inputVariable1.addTerm(new Trapezoid("C", 2, 7, 11, 16));
        inputVariable1.addTerm(new Trapezoid("W", 12, 16, 20, 24));
        inputVariable1.addTerm(new Trapezoid("H", 22, 26, 28, 32));
        inputVariable1.addTerm(new Trapezoid("TH", 30, 34, 40, 40));
        inputVariable1.setRange(0.00, 40.00);

        engine.addInputVariable(inputVariable1);

        inputVariable2 = new InputVariable();
        inputVariable2.setEnabled(true);
        inputVariable2.setName("targetTemp");
        
        // Set the range and terms for the target temperature input
        inputVariable2.addTerm(new Trapezoid("TC", 0, 1, 4, 7));
        inputVariable2.addTerm(new Trapezoid("C", 2, 7, 11, 16));
        inputVariable2.addTerm(new Trapezoid("W", 12, 16, 20, 24));
        inputVariable2.addTerm(new Trapezoid("H", 22, 26, 28, 32));
        inputVariable2.addTerm(new Trapezoid("TH", 30, 34, 40, 40));
        inputVariable2.setRange(0.00, 40.00);
        // Add the variable to the fuzzy engine
        engine.addInputVariable(inputVariable2);


        outputVariable = new OutputVariable();
        outputVariable.setEnabled(true);
        outputVariable.setName("command");
        outputVariable.fuzzyOutput().setAggregation(new Maximum());
        outputVariable.setDefuzzifier(new Centroid(200));
        outputVariable.setDefaultValue(Double.NaN);
        outputVariable.setLockPreviousValue(false);

        // Set the range and terms for the command output
        outputVariable.addTerm(new Trapezoid("cool", -10.0, -5, -2.5, -1.5));
        outputVariable.addTerm(new Triangle("normal", -2, 0, 2));
        outputVariable.addTerm(new Trapezoid("heat",  1.5, 2.5, 5, 10));    
        outputVariable.setRange(-10.00, 10.00);
        // Add the variable to the fuzzy engine
        engine.addOutputVariable(outputVariable);

        ruleBlock = new RuleBlock();
        ruleBlock.setEnabled(true);
        ruleBlock.setName("Rule Block");
        ruleBlock.setConjunction(new Minimum());
        ruleBlock.setDisjunction(new Maximum());
        ruleBlock.setImplication(new Minimum());
        ruleBlock.setActivation(new General());

        // Add rules to the rule block
        ruleBlock.addRule(Rule.parse("if roomTemp is TC and targetTemp is TC then command is normal", engine));
        ruleBlock.addRule(Rule.parse("if roomTemp is C and targetTemp is C then command is normal", engine));
        ruleBlock.addRule(Rule.parse("if roomTemp is W and targetTemp is W then command is normal", engine));
        ruleBlock.addRule(Rule.parse("if roomTemp is H and targetTemp is H then command is normal", engine));
        ruleBlock.addRule(Rule.parse("if roomTemp is TH and targetTemp is TH then command is normal", engine));

        ruleBlock.addRule(Rule.parse("if (roomTemp is TH or roomTemp is H or roomTemp is W  or roomTemp is C) and (targetTemp is TC) then command is cool", engine));
     
        ruleBlock.addRule(Rule.parse("if (roomTemp is TH or roomTemp is H or roomTemp is W) and (targetTemp is C) then command is cool", engine));
        ruleBlock.addRule(Rule.parse("if (roomTemp is TC) and targetTemp is C then command is heat", engine));
        

        ruleBlock.addRule(Rule.parse("if (roomTemp is TC or roomTemp is C) and targetTemp is W then command is heat", engine));
        ruleBlock.addRule(Rule.parse("if (roomTemp is TH or roomTemp is H) and targetTemp is W then command is cool", engine));
        
        ruleBlock.addRule(Rule.parse("if (roomTemp is TC or roomTemp is C or roomTemp is W) and (targetTemp is H) then command is heat", engine));
        ruleBlock.addRule(Rule.parse("if (roomTemp is TH) and targetTemp is H then command is cool", engine));
        
        ruleBlock.addRule(Rule.parse("if (roomTemp is W or roomTemp is H or roomTemp is TC or roomTemp is C) and (targetTemp is TH) then command is heat", engine));
        
        engine.addRuleBlock(ruleBlock);
}

private float fuzzyACEvaluate(float rt, float tt){
    
    
    inputVariable1.setValue(rt); // room temp
    inputVariable2.setValue(tt); // target temp
    // Run the engine
    engine.process();
    // Get the output
    outputVariable.defuzzify();
    return (float)(outputVariable.getValue());

}

void draw() {
    drawSystem();
}
