/*
Copyright (c) 2015, Radial Web, Inc. 

Redistribution and use in source and binary forms, with or without modification, 
are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, 
    this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, 
    this list of conditions and the following disclaimer in the documentation 
    and/or other materials provided with the distribution.
    * Neither the name of the Radial Web, Inc. nor the names of its contributors 
    may be used to endorse or promote products derived from this software 
    without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED 
OF THE POSSIBILITY OF SUCH DAMAGE.
*/

global class UserMetricsJob implements Database.Batchable<sObject>,Database.Stateful {

    /**
    * @description Build query for all active users
    */
    global Database.QueryLocator start(Database.BatchableContext BC) {  
        
        //check the status of each metric report in custom settings.
        updateMetricReportStatus();
        
        //Build the query for each active user.
        String query = 'SELECT ID, Name, Alias, IsActive FROM User WHERE IsActive = true ORDER BY Alias';
        return Database.getQueryLocator(query);
    }
    
    /**
    * @description. Iterate through each user record and process all configured reports for that user.
    * Save resulting Sales Metric records for each user.
    */
    global void execute(Database.BatchableContext BC, List<User> scope){      
        //Process metrics for each user 
        for (User usr:  scope) {            
            new UserMetricsProcess().generateMetrics(usr);     
        }
    }
    
    /**
    * 
    */
    global void finish(Database.BatchableContext BC) {
        //Finish code goes here
    }
    
    /**
    * @description loop through all metrics reports and check their instanceId to make sure they have all completed.
    */
    private void updateMetricReportStatus() {
        List<Metrics_Reports__c> metricReports = Metrics_Reports__c.getAll().values();
        for (Metrics_Reports__c mr : metricReports) { 
            if (mr.Active__c == true && mr.Instance_ID__c != null) {            
                //Add the report's Instance ID (this is how to retrive report results from Reporting API cache...stored for up to 24 hours when reports are run asyncronously)
                Reports.ReportInstance instance = Reports.ReportManager.getReportInstance(mr.Instance_ID__c);
                mr.Status__c = instance.getStatus();  
            }
        }
        
        //Save status changes to Metric Reports
        update metricReports;
    }
}