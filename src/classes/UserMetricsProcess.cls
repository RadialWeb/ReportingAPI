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

public class UserMetricsProcess {

    /**
    * @description process all reports for a single user. Update resulting Sales Metrics records
    */
    public void generateMetrics(User usr) {       
		List<Metrics_Reports__c> metricReports = Metrics_Reports__c.getAll().values();
        
        //Create a new Sales Metric custom object for this user
        Sales_Metrics__c userSalesMetric = new Sales_Metrics__c(Key__c = usr.ID);
        userSalesMetric.Sales_Rep__c = usr.ID;
        userSalesMetric.Name = usr.Name;
        
        //Loop through each report and process results.
        for (Metrics_Reports__c mr : metricReports) {  
            if (mr.Active__c == true && mr.Instance_ID__c != null) {
            	processReport(mr, usr, userSalesMetric);
            }
        }
        
        //update the sales metric
        Database.upsert(userSalesMetric, Sales_Metrics__c.Key__c, false);  
    }
    
    /**
    * @description Process a single report for a given User. 
    */
    private void processReport(Metrics_Reports__c metricReport, User usr, Sales_Metrics__c userSalesMetric) {        
        //Get the report instance.
        Reports.ReportInstance instance = Reports.ReportManager.getReportInstance(metricReport.Instance_ID__c);
        Reports.ReportResults results = instance.getReportResults();       
        Reports.Dimension dim = results.getGroupingsDown();
        
        //Retrieve the field mapping defined in the Metric Report custom object. 
        Map<String, String> fieldMap = getFieldMap(metricReport.Field_Mapping__c);
        
        //Report results don't provide a friendly way to get to aggregate values by Column name. We build that ability manually here.
        //Note we do this for each report since each report's column indexes *could* be different
        Map<String, Integer> reportColumns = getReportColumnIndexMap(results);
        
        //Loop through all Group Headers looking for any that match the current user
        for (Reports.GroupingValue userGroup : dim.getGroupings()) {
			String userAlias = userGroup.getLabel(); //Get the User alias for group header comparison
            if (userAlias == usr.Alias) {
                Reports.ReportFactWithSummaries factSummaries = (Reports.ReportFactWithSummaries)results.getFactMap().get(userGroup.getKey() + '!T');
                List<Reports.SummaryValue> summaryValues = factSummaries.getAggregates();
                processGroupData(usr, summaryValues, reportColumns, fieldMap, userSalesMetric);
            }
        }
    }
    
    /**
    * @description Process all the data within a single report grouping...already determined to match the specified user.
    * This implementation only processes YTD data and populates on Latest Month Sales Metric. 
    * This can be overridded by an implementation class if a set of reports uses a different grouping format.
    */
    private virtual void processGroupData(User usr, List<Reports.SummaryValue> summaryValues, Map<String, Integer> reportColumns, Map<String, String> fieldMap, Sales_Metrics__c userSalesMetric) {
		//Get the latest metric for this user. Not querying data, just Instantiating new and setting external key (and prepopulating appropriate fields to 0).
        for (String metricFieldName : fieldMap.keySet()) {
            try {
                String reportColumnName = fieldMap.get(metricFieldName);
                if (reportColumnName != null) {
                    Integer columnIndex = reportColumns.get(reportColumnName); 
                    //found a matching column name
                    if (columnIndex != null) {
                        Decimal metricValue = (Decimal)userSalesMetric.get(metricFieldName);
                        Decimal reportValue = (Decimal)summaryValues[columnIndex].getValue();
                        if (reportValue != null) {
                            metricValue = (metricValue == null) ? reportValue : (metricValue + reportValue);
                            userSalesMetric.put(metricFieldName, metricValue);
                        }
                    } else {
                        System.debug(metricFieldName + ' NOT FOUND');
                        //It's ok if there isn't a match. It just means the current considered field isn't relevant for the current report
                    }
                }
            } catch (Exception e) { //Catch and log any errors and keep going
                System.debug('**ERROR: ' + metricFieldName + '--' + e.getMessage());
            }
        }  
    }
    
    /**
    * build the map of Sales Metric field to report column title based on text string stored in custom setting
    */
    private Map<String, String> getFieldMap(String mapString) {
        Map<String, String> fieldMap = new Map<String, String>();
        List<String> rows = mapString.split('\n');
        for (String row : rows) {
            List<String> rowParts = row.split(';');
            if (rowParts.size() == 2) {
                fieldMap.put(rowParts[0].trim(),rowParts[1].trim());
            }
        }
        return fieldMap;
    }
    
    /**
    * @description Build a correlation between Column Name and Column Index so that it's easily referenced.
    */
    private Map<String, Integer> getReportColumnIndexMap(Reports.ReportResults results) {
		Reports.ReportMetadata reportMeta = results.getReportMetadata();
		Reports.ReportExtendedMetadata extMeta = results.getReportExtendedMetadata();
        Map<String,Reports.AggregateColumn> colInfo = extMeta.getAggregateColumnInfo();
        Map<String, Integer> colMap = new Map<String, Integer>();
        Integer j = 0;
        for (String colName : reportMeta.getAggregates()) {
            colMap.put(colInfo.get(colName).getLabel(), j++);
        }
        return colMap;
    }
    
}