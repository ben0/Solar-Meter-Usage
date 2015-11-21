#undef int()
#include <SPI.h>
#include <Ethernet.h>

// Ethernet variables
byte mac[] = { 0xCC, 0xAC, 0xBE, 0xEF, 0xFE, 0x91 };
byte ip[] = { 172, 16, 100, 164 };
byte gateway[] = { 172, 16, 200, 1 };
byte subnet[]= { 255, 255, 0, 0 };
Server server = Server(80);

// Units and kWh
int revsPerkWh = 500; // Revolutions per kWh, should be on the front of your meter

// Variables we use to detect triggers
unsigned long interval = 0;
boolean lightOn = false;
boolean e_score = 0;
int sensorvals[] = {1000, 1000, 1000};

// Elec
float elecUnits[] = {0,0,0};  // total,current,avg
unsigned long elecCounts[] = {0,0,0,0}; //  total rev counter, last interval time, last interval rev counter, average interval time

int sensorDelay = 20;                      // was 20
int powerPin = 6;

void setup()
{
    Serial.begin(9600);
    Ethernet.begin(mac,ip,gateway,subnet);
    server.begin();
    pinMode(powerPin, OUTPUT);
    elecCounts[1] = millis();
    elecCounts[3] = millis();
    delay(1000);
}
    
void loop()
{
    getReading();
    check4conn();
    
}
    
void getReading()
{ 
    digitalWrite(powerPin, HIGH);
    delay(sensorDelay);
    
    // Populate the arrays
    
    int sensorVal = analogRead(3);
    // Serial.print(sensorVal);
    // Serial.print("\n");
    
    for (int k = 0; k < 2; k++)
    {   
        sensorvals[k] = sensorvals[k+1]; 
    }
    
    sensorvals[2] = sensorVal;

    if(sensorvals[2] > 400 && sensorvals[1] > 400 && sensorvals[0] > 400)
    {
      e_score = 1;
    } else {
      e_score = 0;
    }    
    
    // Electricity
    if(lightOn == false && e_score == 1)
    {
      
      print_serial();
        long currentTime = millis();
        
        lightOn = true;
        interval = currentTime - elecCounts[1];
        
        elecUnits[0] = (float)elecCounts[0] / (float)revsPerkWh;  // Total kWh
        elecUnits[1] = (3600000.0 / interval) / revsPerkWh;         // Current kWh
        
        elecCounts[0]++;        // Increment Total Rev Counter
        elecCounts[2]++;        // Increment last interval Rev counter

        if ((currentTime - elecCounts[3]) > 1800000)
        {
            elecUnits[2] = 0;       // Reset the Avg
            elecUnits[2] = elecUnits[0] / elecCounts[2];        // Calc the Avg.
            elecCounts[3] = currentTime;                        // Update the last interval time to now, ensure the next avg will be calc over this period
            elecCounts[2] = 0;                                  // Reset the average rev counter
        }
        elecCounts[1] = millis();
     } else if(e_score == 0)
    {
           lightOn = false;
    }
}

void print_serial()
{
        Serial.print("\n\n----Electricity----");
        Serial.print("\nInterval: ");
        Serial.print(interval);
        Serial.print("\nCurrent kWh: ");
        Serial.print(elecUnits[1]);
        Serial.print("\nTotal kWh: ");
        Serial.print(elecUnits[0]);
        Serial.print("\n30 min Avg kWh: ");
        Serial.print(elecUnits[2]);
        Serial.print("\nTotal Rev Counter: ");
        Serial.print(elecCounts[0]);
}

void check4conn()
{
    Client client = server.available();
    if (client) 
    {
        // an http request ends with a blank line
        boolean current_line_is_blank = true;
        while (client.connected()) 
        {
            if (client.available())
            {
                char c = client.read();
                // if we've gotten to the end of the line (received a newline
                // character) and the line is blank, the http request has ended,
                // so we can send a reply
                if (c == '\n' && current_line_is_blank)
                {
                    // send a standard http response header
                    client.println("HTTP/1.1 200 OK");
                    client.println("Content-Type: text/html");
                    client.println();
                    
                    client.print("Time since boot: ");
                    client.print(millis() / 1000);
                    
                    client.print("<br />");
                    client.print("<br />");
                    
                    client.print("<br />");
                    client.print("<br />");
                    
                    client.print("Elec Usage: ");
                    client.print("<br />");
                    client.print("Current kWh: ");
                    client.print(elecUnits[1]);
                    client.print("<br />");
                    client.print("Total kWh: ");
                    client.print(elecUnits[0]);
                    client.print("<br />");
                    client.print("30 min Avg kWh: ");
                    client.print(elecUnits[2]);
           
                    client.print("<br />");
                    break;
                }
                if (c == '\n')
                {
                    // we're starting a new line
                    current_line_is_blank = true;
                } else if (c != '\r')
                {
                    // we've gotten a character on the current line
                    current_line_is_blank = false;
                }
            }
        }
        // give the web browser time to receive the data
        delay(10);
        client.stop();
    }
}

