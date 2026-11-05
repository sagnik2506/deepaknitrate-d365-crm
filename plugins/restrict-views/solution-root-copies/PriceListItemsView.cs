using Microsoft.Crm.Sdk.Messages;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Restrict_Views
{
    public class PriceListItemsView : IPlugin
    {
        public void Execute(IServiceProvider serviceProvider)
        {
            try
            {
                IPluginExecutionContext context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));

                IOrganizationServiceFactory serviceFactory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));

                IOrganizationService service = serviceFactory.CreateOrganizationService(context.UserId);

                ITracingService tracingService = (ITracingService)serviceProvider.GetService(typeof(ITracingService));
                if ((context.MessageName.Equals("RetrieveMultiple")))
                {
                    tracingService.Trace("1");
                    tracingService.Trace("Mode  " + context.Mode.ToString());
                    string SecurityXML = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='true'>" +
"  <entity name='role'>" +
"    <attribute name='name' />" +
"    <attribute name='businessunitid' />" +
"    <attribute name='roleid' />" +
"    <order attribute='name' descending='false' />" +
"    <filter type='and'>" +
"      <condition attribute='name' operator='eq' value='System Administrator' />" +
"    </filter>" +
"    <link-entity name='systemuserroles' from='roleid' to='roleid' visible='false' intersect='true'>" +
"      <link-entity name='systemuser' from='systemuserid' to='systemuserid' alias='af'>" +
"        <filter type='and'>" +
"          <condition attribute='systemuserid' operator='eq' value='" + context.InitiatingUserId.ToString() + "' />" +
"        </filter>" +
"      </link-entity>" +
"    </link-entity>" +
"  </entity>" +
"</fetch>";
                    EntityCollection Roles = service.RetrieveMultiple(new FetchExpression(SecurityXML));
                    tracingService.Trace("Roles Count " + Roles.Entities.Count());
                    if (Roles.Entities.Count == 0)
                    {
                        bool subgrid = false;
                        QueryExpression PPI = new QueryExpression();
                        if (context.InputParameters["Query"] is QueryExpression)
                        {

                        }
                        else if (context.InputParameters["Query"] is FetchExpression)
                        {
                            FetchExpression fetch = context.InputParameters["Query"] as FetchExpression;
                            FetchXmlToQueryExpressionRequest conversionRequest = new FetchXmlToQueryExpressionRequest()
                            {
                                FetchXml = fetch.Query
                            };
                            FetchXmlToQueryExpressionResponse conversionResponse = (service.Execute(conversionRequest) as FetchXmlToQueryExpressionResponse);
                            PPI = conversionResponse.Query;
                            foreach (var link in PPI.LinkEntities)
                            {
                                if (link.LinkCriteria.Conditions.Count > 0)
                                {
                                    foreach (var lc in link.LinkCriteria.Conditions)
                                    {
                                        if (lc.AttributeName == "pricelevelid")
                                        {
                                            subgrid = true;
                                        }
                                    }
                                }
                            }

                        }
                        if (subgrid == true)
                        {
                            context.InputParameters["Query"] = PPI;
                        }
                        else
                        {
                            // Create the QueryExpression object for the 'productpricelevel' entity
                            string fetchxml = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='false'>" +
    "  <entity name='productpricelevel'>" +
    "    <attribute name='productid' />" +
    "    <attribute name='uomid' />" +
        "    <attribute name='dg_approvalstatus' />" +
    "    <attribute name='productpricelevelid' />" +
    "    <order attribute='productid' descending='false' />" +
    "    <link-entity name='product' from='productid' to='productid' link-type='inner' alias='ad'>" +
    "      <link-entity name='dg_materialgroup' from='dg_materialgroupid' to='dg_materialgroup' link-type='inner' alias='ae'>" +
    "        <filter type='and'>" +
    "          <condition attribute='dg_division' operator='not-in'>" +
    "            <value>30</value>" +
    "            <value>100</value>" +
    "            <value>90</value>" +
    "            <value>40</value>" +
    "            <value>50</value>" +
    "          </condition>" +
    "        </filter>" +
    "      </link-entity>" +
    "    </link-entity>" +
    "<link-entity name='pricelevel' from='pricelevelid' to='pricelevelid' visible='false' link-type='outer' alias='a_5bdeae41b1a3ed11aad1002248d5de64'>" +
"      <attribute name='createdon' />" +
"      <attribute name='pricelevelid' />" +
"    </link-entity>" +
    "  </entity>" +
    "</fetch>";
                            FetchExpression fetchexp = new FetchExpression(fetchxml);
                            context.InputParameters["Query"] = fetchexp;
                        }
                    }
                }

            }
            catch (Exception ex)
            {
                throw new InvalidPluginExecutionException(ex.Message);
            }
        }
    }
}
