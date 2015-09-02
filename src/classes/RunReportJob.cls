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

global class RunReportJob implements Schedulable {
    
    
    /*
    * @description Create stored instances of result data for reports defined in Metrics Reports custom setting
    */
	global void execute(SchedulableContext ctx) {
        
        //Get all configured Metric_Reports custom settings
        List<Metrics_Reports__c> metricReports = Metrics_Reports__c.getAll().values();
        Set<String> reportNames = new Set<String>();
        for (Metrics_Reports__c mr : metricReports) {
            reportNames.add(mr.Report_Developer_Name__c);
        }
        
        //Match Report Developer Names to actual Report IDs
        Map<String, ID> reportMap = getReportMap(reportNames);
        
        for (Metrics_Reports__c mr : metricReports) {
            try {
                if (mr.Active__c == true) { 
                    //get the matching report ID for the Developer Name
                    System.debug('METRIC REPORT: ' + mr);
                    ID reportId = reportMap.get(mr.Report_Developer_Name__c); 
                    if (reportId != null) {
                        Reports.ReportInstance instance = Reports.ReportManager.runAsyncReport(reportId, false); //false tells to not include report details. Summary only     
                        
                        //Update the Metric Report record with the instance ID for later reference
                        mr.Instance_ID__c = instance.getId();
                        mr.Last_Run__c = System.now();
                        mr.Status__c = instance.getStatus();
                        System.debug('REPORT RUN: ' + mr);
                    } else {
                        mr.Status__c = 'NOT FOUND';
                        mr.Last_Run__c = null;
                        mr.Instance_ID__c = null;
                        System.debug('REPORT NOT FOUND: ' + mr);
                    }
                }
            } catch (Exception e) {
                System.debug('REPORT ERROR: ' + mr.Name + '--' + e.getMessage());
                mr.Status__c = 'ERROR';
                mr.Last_Run__c = null;
                mr.Instance_ID__c = null;
            }
            //Save updates to metricReports
            update metricReports;
        }
    }
    
    /*
    * @description find all reportIds that match the requested set of developer names
    */
    private Map<String, ID> getReportMap(Set<String> reportNames) {
        Map<String, ID> reportMap = new Map<String, ID>();
        List<Report> reports = [SELECT ID, DeveloperName FROM Report WHERE DeveloperName IN :reportnames];
        for (Report rep : reports) {
            reportMap.put(rep.DeveloperName, rep.ID);
        }
        return reportMap;
    }
    
    
}