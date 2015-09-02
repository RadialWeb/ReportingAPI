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
@isTest
public class UserMetrics_Test {
    //public static Set<ID> metricReportIds;
    public static User testUser1;
    public static User testUser2;
    public static User testUser3;
    
    static void setupData() {
        
		//Create a test account. this matches up to a test report named Unit Test Sample Report        
        Account testAcct1 = new Account(Name = 'Metrics Test Account 1');
        testAcct1.OwnerId = UserInfo.getUserId();        
        insert testAcct1;
        
        
        //The following code deactivates all the existing Metrics Reports custom settings definitions and then adds to new records.
        //This is for unit test efficiency since these tests run with SeeAllData. We don't want the test to run all the existing defined reports...that would take too long.
        //Instead we have a Unit Test Sample Report that will only return 1 record....the account named Metrics Test Account 1.
        List<Metrics_Reports__c> metricsReports = Metrics_Reports__c.getAll().values();
        for (Metrics_Reports__c mr : metricsReports) {
            mr.active__c = false; //deactivate all existing custom settings so that they do not get run.
        }
        
        //Add a sample report that will return very limited data
        metricsReports.add(new Metrics_Reports__c(Name='Unit Test', Active__c=true, Report_Developer_Name__c = 'Unit_Test_Sample_Report', Field_Mapping__c='Managed_Accounts__c;Managed_Accounts'));
        
        //Add another record that will NOT find a matching report. This is for unit test coverage.
        metricsReports.add(new Metrics_Reports__c(Name='Unit Test NOT FOUND', Active__c=true, Report_Developer_Name__c = 'NOT_FOUND_METRICS_REPORT', Field_Mapping__c='Managed_Accounts__c;Managed_Accounts'));
        upsert metricsReports;
          
    }
    
    @isTest(seeAllData=true) //Notice the seeAllData. This is required for Analytics API....otherwise the test code cannot access Reports.
    static void testRunReports() {
        //create some test data
        setupData();
        
        Test.startTest();
        RunReportJob reportJob = new RunReportJob();
        reportJob.execute(null);
        Test.stopTest(); //Note this is important...since reports are run asychronously...the test won't pass this line until reports are done.
        
        UserMetricsJob job = new UserMetricsJob();
        User usr = [SELECT ID, Alias, Name FROM User WHERE ID = :UserInfo.getUserId()];
        job.start(null);
        
        //Run the batch job for just this user.
        List<User> users = new List<User> {usr};
        job.execute(null, users);  
        job.finish(null);
        
        //Verify the results
        Sales_Metrics__c metric = [SELECT ID, Managed_Accounts__c FROM Sales_Metrics__c WHERE Sales_Rep__c = :UserInfo.getUserId() LIMIT 1];
        System.assertEquals(1, metric.Managed_Accounts__c);
    }
}