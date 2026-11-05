using Microsoft.Crm.Sdk.Messages;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml;

namespace Restrict_Views
{
    public class LeadView : IPlugin
    {
        public void Execute(IServiceProvider serviceProvider)
        {
            try
            {
                IPluginExecutionContext context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));

                IOrganizationServiceFactory serviceFactory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));

                IOrganizationService service = serviceFactory.CreateOrganizationService(context.UserId);
                ITracingService tracingService = (ITracingService)serviceProvider.GetService(typeof(ITracingService));
                if(context.MessageName.Equals("RetrieveMultiple"))
                {
                    string fetchXml = string.Empty;
                    if (context.InputParameters["Query"] is QueryExpression)
                    {
                        QueryExpression query = (QueryExpression)context.InputParameters["Query"];
                        var qeToFetchXmlRequest = new QueryExpressionToFetchXmlRequest
                        {
                            Query = query
                        };
                        var qeToFetchXmlResponse = (QueryExpressionToFetchXmlResponse)service.Execute(qeToFetchXmlRequest);
                        fetchXml = qeToFetchXmlResponse.FetchXml;
                    }
                    else if (context.InputParameters["Query"] is FetchExpression)
                    {
                        FetchExpression fetch = context.InputParameters["Query"] as FetchExpression;
                        fetchXml = fetch.Query;
                    }
                    if (fetchXml != null && fetchXml != string.Empty)
                    {
                        XmlDocument xmlDoc = new XmlDocument();
                        xmlDoc.LoadXml(fetchXml);
                        string SecurityXML = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='false'>" +
                        "  <entity name='systemuser'>" +
                        "    <attribute name='systemuserid' />" +
                        "    <attribute name='dg_salesorganization' />" +
                        "    <attribute name='dg_salesorganizationmulti' />" +
                        "    <filter type='and'>" +
                        "      <condition attribute='systemuserid' operator='eq' value='" + context.InitiatingUserId.ToString() + "'/>" +
                        "    </filter>" +
                        "  </entity>" +
                        "</fetch>";
                        EntityCollection Roles = service.RetrieveMultiple(new FetchExpression(SecurityXML));
                        if (Roles != null && Roles.Entities.Count > 0)
                        {
                            if (Roles.Entities[0].Attributes.Contains("dg_salesorganizationmulti"))
                            {
                                var MultiSalesOrg = Roles.Entities[0].GetAttributeValue<OptionSetValueCollection>("dg_salesorganizationmulti");
                                if (MultiSalesOrg != null && MultiSalesOrg.Count > 0)
                                {
                                    if (MultiSalesOrg.Count == 1)
                                    {
                                        OptionSetValue SalesOrg = new OptionSetValue(MultiSalesOrg.First().Value);
                                        if (SalesOrg != null && SalesOrg.Value == 2000)
                                        {
                                            XmlNamespaceManager nsmgr = new XmlNamespaceManager(xmlDoc.NameTable);
                                            XmlNode filterNode = xmlDoc.SelectSingleNode("//entity/filter", nsmgr);
                                            if (filterNode == null)
                                            {
                                                filterNode = xmlDoc.CreateElement("filter");
                                                XmlAttribute typeAttribute = xmlDoc.CreateAttribute("type");
                                                typeAttribute.Value = "and";
                                                filterNode.Attributes.Append(typeAttribute);

                                                // Find the <entity> node where filter should be added
                                                XmlNode entityNode = xmlDoc.SelectSingleNode("//entity");

                                                // Append the <filter> to the <entity> node
                                                entityNode.AppendChild(filterNode);
                                            }
                                            if (filterNode != null)
                                            {
                                                XmlElement newCondition = xmlDoc.CreateElement("condition");
                                                newCondition.SetAttribute("attribute", "dg_salesorg");
                                                newCondition.SetAttribute("operator", "eq");
                                                newCondition.SetAttribute("value", SalesOrg.Value.ToString());

                                                filterNode.AppendChild(newCondition);
                                                string updatedFetchXml = xmlDoc.OuterXml;
                                                context.InputParameters["Query"] = new FetchExpression(updatedFetchXml);
                                            }
                                        }
                                        else if (SalesOrg != null && SalesOrg.Value == 1000)
                                        {
                                            XmlNamespaceManager nsmgr = new XmlNamespaceManager(xmlDoc.NameTable);
                                            XmlNode filterNode = xmlDoc.SelectSingleNode("//entity/filter", nsmgr);
                                            if (filterNode == null)
                                            {
                                                filterNode = xmlDoc.CreateElement("filter");
                                                XmlAttribute typeAttribute = xmlDoc.CreateAttribute("type");
                                                typeAttribute.Value = "and";
                                                filterNode.Attributes.Append(typeAttribute);

                                                // Find the <entity> node where filter should be added
                                                XmlNode entityNode = xmlDoc.SelectSingleNode("//entity");

                                                // Append the <filter> to the <entity> node
                                                entityNode.AppendChild(filterNode);
                                            }
                                            if (filterNode != null)
                                            {
                                                XmlElement newCondition = xmlDoc.CreateElement("condition");
                                                newCondition.SetAttribute("attribute", "dg_salesorg");
                                                newCondition.SetAttribute("operator", "eq");
                                                newCondition.SetAttribute("value", SalesOrg.Value.ToString());
                                                filterNode.AppendChild(newCondition);

                                                string FetchXML = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='true'>" +
            "  <entity name='team'>" +
            "    <attribute name='teamid' />" +
            "    <filter type='and'>" +
            "      <condition attribute='teamtype' operator='ne' value='1' />" +
            "    </filter>" +
            "    <link-entity name='teammembership' from='teamid' to='teamid' visible='false' intersect='true'>" +
            "      <link-entity name='systemuser' from='systemuserid' to='systemuserid' alias='ac'>" +
            "        <filter type='and'>" +
            "          <condition attribute='systemuserid' operator='eq' value='" + context.InitiatingUserId.ToString() + "'/>" +
            "        </filter>" +
            "      </link-entity>" +
            "    </link-entity>" +
            "    <link-entity name='businessunit' from='businessunitid' to='businessunitid' visible='false' link-type='outer' alias='bu'>" +
            "      <attribute name='name' />" +
            "    </link-entity>" +
            "  </entity>" +
            "</fetch>";
                                                EntityCollection teams = service.RetrieveMultiple(new FetchExpression(FetchXML));
                                                if (teams != null && teams.Entities.Count > 0)
                                                {
                                                    bool bi = false;
                                                    bool fs = false;
                                                    bool pp = false;
                                                    foreach (Entity te in teams.Entities)
                                                    {
                                                        string bsu = (string)((AliasedValue)te.Attributes["bu.name"]).Value;
                                                        if (bsu.ToLower() == "bi")
                                                        {
                                                            bi = true;
                                                        }
                                                        if (bsu.ToLower() == "f&s")
                                                        {
                                                            fs = true;
                                                        }
                                                        if (bsu.ToLower() == "pp")
                                                        {
                                                            pp = true;
                                                        }
                                                    }
                                                    XmlElement newCondition1 = xmlDoc.CreateElement("condition");
                                                    newCondition1.SetAttribute("attribute", "dg_division");

                                                    if (bi == true && fs == false && pp == false)
                                                    {
                                                        newCondition1.SetAttribute("operator", "eq");
                                                        newCondition1.SetAttribute("value", "30");
                                                        filterNode.AppendChild(newCondition1);
                                                    }
                                                    else if (bi == false && fs == true && pp == false)
                                                    {
                                                        newCondition1.SetAttribute("operator", "eq");
                                                        newCondition1.SetAttribute("value", "40");
                                                        filterNode.AppendChild(newCondition1);
                                                    }
                                                    else if (bi == false && fs == false && pp == true)
                                                    {
                                                        newCondition1.SetAttribute("operator", "eq");
                                                        newCondition1.SetAttribute("value", "50");
                                                        filterNode.AppendChild(newCondition1);
                                                    }
                                                    else if ((bi && fs) || (bi && pp) || (fs && pp)) // any 2 or all 3
                                                    {
                                                        newCondition1.SetAttribute("operator", "in");

                                                        // Dynamically add only selected values
                                                        if (bi)
                                                        {
                                                            XmlElement valueElement = xmlDoc.CreateElement("value");
                                                            valueElement.InnerText = "30";
                                                            newCondition1.AppendChild(valueElement);
                                                        }
                                                        if (fs)
                                                        {
                                                            XmlElement valueElement = xmlDoc.CreateElement("value");
                                                            valueElement.InnerText = "40";
                                                            newCondition1.AppendChild(valueElement);
                                                        }
                                                        if (pp)
                                                        {
                                                            XmlElement valueElement = xmlDoc.CreateElement("value");
                                                            valueElement.InnerText = "50";
                                                            newCondition1.AppendChild(valueElement);
                                                        }

                                                        filterNode.AppendChild(newCondition1);
                                                    }



                                                }
                                                string updatedFetchXml = xmlDoc.OuterXml;
                                                context.InputParameters["Query"] = new FetchExpression(updatedFetchXml);
                                            }
                                        }
                                        else if (SalesOrg != null && SalesOrg.Value == 3000)
                                        {
                                            XmlNamespaceManager nsmgr = new XmlNamespaceManager(xmlDoc.NameTable);
                                            XmlNode filterNode = xmlDoc.SelectSingleNode("//entity/filter", nsmgr);
                                            if (filterNode == null)
                                            {
                                                filterNode = xmlDoc.CreateElement("filter");
                                                XmlAttribute typeAttribute = xmlDoc.CreateAttribute("type");
                                                typeAttribute.Value = "and";
                                                filterNode.Attributes.Append(typeAttribute);

                                                // Find the <entity> node where filter should be added
                                                XmlNode entityNode = xmlDoc.SelectSingleNode("//entity");

                                                // Append the <filter> to the <entity> node
                                                entityNode.AppendChild(filterNode);
                                            }
                                            if (filterNode != null)
                                            {
                                                XmlElement newCondition = xmlDoc.CreateElement("condition");
                                                newCondition.SetAttribute("attribute", "dg_salesorg");
                                                newCondition.SetAttribute("operator", "eq");
                                                newCondition.SetAttribute("value", SalesOrg.Value.ToString());
                                                filterNode.AppendChild(newCondition);

                                                string FetchXML = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='true'>" +
            "  <entity name='team'>" +
            "    <attribute name='teamid' />" +
            "    <filter type='and'>" +
            "      <condition attribute='teamtype' operator='ne' value='1' />" +
            "    </filter>" +
            "    <link-entity name='teammembership' from='teamid' to='teamid' visible='false' intersect='true'>" +
            "      <link-entity name='systemuser' from='systemuserid' to='systemuserid' alias='ac'>" +
            "        <filter type='and'>" +
            "          <condition attribute='systemuserid' operator='eq' value='" + context.InitiatingUserId.ToString() + "'/>" +
            "        </filter>" +
            "      </link-entity>" +
            "    </link-entity>" +
            "    <link-entity name='businessunit' from='businessunitid' to='businessunitid' visible='false' link-type='outer' alias='bu'>" +
            "      <attribute name='name' />" +
            "    </link-entity>" +
            "  </entity>" +
            "</fetch>";
                                                EntityCollection teams = service.RetrieveMultiple(new FetchExpression(FetchXML));
                                                if (teams != null && teams.Entities.Count > 0)
                                                {
                                                    bool bi = false;
                                                    bool fs = false;
                                                    bool ec = false;
                                                    bool solvent = false;
                                                    foreach (Entity te in teams.Entities)
                                                    {
                                                        string bsu = (string)((AliasedValue)te.Attributes["bu.name"]).Value;
                                                        if (bsu.ToLower() == "bi")
                                                        {
                                                            bi = true;
                                                        }
                                                        if (bsu.ToLower() == "f&s")
                                                        {
                                                            fs = true;
                                                        }
                                                        if (bsu.ToLower() == "ec")
                                                        {
                                                            ec = true;
                                                        }
                                                        if (bsu.ToLower() == "solvent")
                                                        {
                                                            solvent = true;
                                                        }
                                                    }
                                                    List<int> division = new List<int>();
                                                    if (bi == true)
                                                    {
                                                        division.Add(30);
                                                    }
                                                    if (fs == true)
                                                    {
                                                        division.Add(40);
                                                    }
                                                    if (ec == true)
                                                    {
                                                        division.Add(95);
                                                    }
                                                    if (solvent == true)
                                                    {
                                                        division.Add(20);
                                                    }
                                                    int[] numbers = division.ToArray();
                                                    XmlElement newCondition1 = xmlDoc.CreateElement("condition");
                                                    newCondition1.SetAttribute("attribute", "dg_division");
                                                    newCondition1.SetAttribute("operator", "in");
                                                    for (int i = 0; i < numbers.Length; i++)
                                                    {
                                                        XmlElement valueElement = xmlDoc.CreateElement("value");
                                                        valueElement.InnerText = numbers[i].ToString();
                                                        newCondition1.AppendChild(valueElement);
                                                    }
                                                    filterNode.AppendChild(newCondition1);
                                                }
                                                string updatedFetchXml = xmlDoc.OuterXml;
                                                context.InputParameters["Query"] = new FetchExpression(updatedFetchXml);
                                            }
                                        }
                                    }
                                    else if(MultiSalesOrg.Count == 2)
                                    {
                                        int salesOrg1 = 0;
                                        int salesOrg2 = 0;
                                        salesOrg1 = MultiSalesOrg[0].Value;
                                        salesOrg2 = MultiSalesOrg[1].Value;
                                        if ((salesOrg1 == 1000 || salesOrg1 == 3000) && (salesOrg2 == 1000 || salesOrg2 == 3000))
                                        {
                                            XmlNamespaceManager nsmgr = new XmlNamespaceManager(xmlDoc.NameTable);
                                            XmlNode filterNode = xmlDoc.SelectSingleNode("//entity/filter", nsmgr);
                                            if (filterNode == null)
                                            {
                                                filterNode = xmlDoc.CreateElement("filter");
                                                XmlAttribute typeAttribute = xmlDoc.CreateAttribute("type");
                                                typeAttribute.Value = "and";
                                                filterNode.Attributes.Append(typeAttribute);

                                                // Find the <entity> node where filter should be added
                                                XmlNode entityNode = xmlDoc.SelectSingleNode("//entity");

                                                // Append the <filter> to the <entity> node
                                                entityNode.AppendChild(filterNode);
                                            }
                                            if (filterNode != null)
                                            {
                                                XmlElement newCondition = xmlDoc.CreateElement("condition");
                                                newCondition.SetAttribute("attribute", "dg_salesorg");
                                                newCondition.SetAttribute("operator", "in");
                                                XmlElement valueElement = xmlDoc.CreateElement("value"); // For Sales Org 1
                                                valueElement.InnerText = salesOrg1.ToString();
                                                newCondition.AppendChild(valueElement);
                                                XmlElement valueElement1 = xmlDoc.CreateElement("value"); // For Sales Org 2
                                                valueElement1.InnerText = salesOrg2.ToString();
                                                newCondition.AppendChild(valueElement1);
                                                filterNode.AppendChild(newCondition);

                                                string FetchXML = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='true'>" +
            "  <entity name='team'>" +
            "    <attribute name='teamid' />" +
            "    <filter type='and'>" +
            "      <condition attribute='teamtype' operator='ne' value='1' />" +
            "    </filter>" +
            "    <link-entity name='teammembership' from='teamid' to='teamid' visible='false' intersect='true'>" +
            "      <link-entity name='systemuser' from='systemuserid' to='systemuserid' alias='ac'>" +
            "        <filter type='and'>" +
            "          <condition attribute='systemuserid' operator='eq' value='" + context.InitiatingUserId.ToString() + "'/>" +
            "        </filter>" +
            "      </link-entity>" +
            "    </link-entity>" +
            "    <link-entity name='businessunit' from='businessunitid' to='businessunitid' visible='false' link-type='outer' alias='bu'>" +
            "      <attribute name='name' />" +
            "    </link-entity>" +
            "  </entity>" +
            "</fetch>";
                                                EntityCollection teams = service.RetrieveMultiple(new FetchExpression(FetchXML));
                                                if (teams != null && teams.Entities.Count > 0)
                                                {
                                                    bool bi = false;
                                                    bool fs = false;
                                                    bool ec = false;
                                                    bool solvent = false;
                                                    bool pp = false;
                                                    foreach (Entity te in teams.Entities)
                                                    {
                                                        string bsu = (string)((AliasedValue)te.Attributes["bu.name"]).Value;
                                                        if (bsu.ToLower() == "bi")
                                                        {
                                                            bi = true;
                                                        }
                                                        if (bsu.ToLower() == "f&s")
                                                        {
                                                            fs = true;
                                                        }
                                                        if (bsu.ToLower() == "ec")
                                                        {
                                                            ec = true;
                                                        }
                                                        if (bsu.ToLower() == "solvent")
                                                        {
                                                            solvent = true;
                                                        }
                                                        if (bsu.ToLower() == "pp")
                                                        {
                                                            pp = true;
                                                        }
                                                    }
                                                    List<int> division = new List<int>();
                                                    if (bi == true)
                                                    {
                                                        division.Add(30);
                                                    }
                                                    if (fs == true)
                                                    {
                                                        division.Add(40);
                                                    }
                                                    if (ec == true)
                                                    {
                                                        division.Add(95);
                                                    }
                                                    if (solvent == true)
                                                    {
                                                        division.Add(20);
                                                    }
                                                    if (pp == true)
                                                    {
                                                        division.Add(50);
                                                    }
                                                    int[] numbers = division.ToArray();
                                                    XmlElement newCondition1 = xmlDoc.CreateElement("condition");
                                                    newCondition1.SetAttribute("attribute", "dg_division");
                                                    newCondition1.SetAttribute("operator", "in");
                                                    for (int i = 0; i < numbers.Length; i++)
                                                    {
                                                        XmlElement valueElement2 = xmlDoc.CreateElement("value");
                                                        valueElement2.InnerText = numbers[i].ToString();
                                                        newCondition1.AppendChild(valueElement2);
                                                    }
                                                    filterNode.AppendChild(newCondition1);
                                                }
                                                string updatedFetchXml = xmlDoc.OuterXml;
                                                context.InputParameters["Query"] = new FetchExpression(updatedFetchXml);
                                            }
                                        }
                                        else if ((salesOrg1 == 2000 || salesOrg1 == 3000) && (salesOrg2 == 2000 || salesOrg2 == 3000))
                                        {
                                            XmlNamespaceManager nsmgr = new XmlNamespaceManager(xmlDoc.NameTable);
                                            XmlNode filterNode = xmlDoc.SelectSingleNode("//entity/filter", nsmgr);
                                            if (filterNode == null)
                                            {
                                                filterNode = xmlDoc.CreateElement("filter");
                                                XmlAttribute typeAttribute = xmlDoc.CreateAttribute("type");
                                                typeAttribute.Value = "and";
                                                filterNode.Attributes.Append(typeAttribute);

                                                // Find the <entity> node where filter should be added
                                                XmlNode entityNode = xmlDoc.SelectSingleNode("//entity");

                                                // Append the <filter> to the <entity> node
                                                entityNode.AppendChild(filterNode);
                                            }
                                            if (filterNode != null)
                                            {
                                                XmlElement orFilter = xmlDoc.CreateElement("filter");
                                                orFilter.SetAttribute("type", "or");

                                                XmlElement salesOrg2000 = xmlDoc.CreateElement("condition");
                                                salesOrg2000.SetAttribute("attribute", "dg_salesorg");
                                                salesOrg2000.SetAttribute("operator", "eq");
                                                salesOrg2000.SetAttribute("value", "2000");
                                                orFilter.AppendChild(salesOrg2000);

                                                XmlElement andFilter = xmlDoc.CreateElement("filter");
                                                andFilter.SetAttribute("type", "and");


                                                XmlElement salesOrg3000 = xmlDoc.CreateElement("condition");
                                                salesOrg3000.SetAttribute("attribute", "dg_salesorg");
                                                salesOrg3000.SetAttribute("operator", "eq");
                                                salesOrg3000.SetAttribute("value", "3000");
                                                andFilter.AppendChild(salesOrg3000);
                                              

                                                string FetchXML = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='true'>" +
            "  <entity name='team'>" +
            "    <attribute name='teamid' />" +
            "    <filter type='and'>" +
            "      <condition attribute='teamtype' operator='ne' value='1' />" +
            "    </filter>" +
            "    <link-entity name='teammembership' from='teamid' to='teamid' visible='false' intersect='true'>" +
            "      <link-entity name='systemuser' from='systemuserid' to='systemuserid' alias='ac'>" +
            "        <filter type='and'>" +
            "          <condition attribute='systemuserid' operator='eq' value='" + context.InitiatingUserId.ToString() + "'/>" +
            "        </filter>" +
            "      </link-entity>" +
            "    </link-entity>" +
            "    <link-entity name='businessunit' from='businessunitid' to='businessunitid' visible='false' link-type='outer' alias='bu'>" +
            "      <attribute name='name' />" +
            "    </link-entity>" +
            "  </entity>" +
            "</fetch>";
                                                EntityCollection teams = service.RetrieveMultiple(new FetchExpression(FetchXML));
                                                if (teams != null && teams.Entities.Count > 0)
                                                {
                                                    bool bi = false;
                                                    bool fs = false;
                                                    bool ec = false;
                                                    bool solvent = false;
                                                  
                                                    foreach (Entity te in teams.Entities)
                                                    {
                                                        string bsu = (string)((AliasedValue)te.Attributes["bu.name"]).Value;
                                                        if (bsu.ToLower() == "bi")
                                                        {
                                                            bi = true;
                                                        }
                                                        if (bsu.ToLower() == "f&s")
                                                        {
                                                            fs = true;
                                                        }
                                                        if (bsu.ToLower() == "ec")
                                                        {
                                                            ec = true;
                                                        }
                                                        if (bsu.ToLower() == "solvent")
                                                        {
                                                            solvent = true;
                                                        }                                                     
                                                    }
                                                    List<int> division = new List<int>();
                                                    if (bi == true)
                                                    {
                                                        division.Add(30);
                                                    }
                                                    if (fs == true)
                                                    {
                                                        division.Add(40);
                                                    }
                                                    if (ec == true)
                                                    {
                                                        division.Add(95);
                                                    }
                                                    if (solvent == true)
                                                    {
                                                        division.Add(20);
                                                    }
                                                   
                                                    int[] numbers = division.ToArray();
                                                    XmlElement newCondition1 = xmlDoc.CreateElement("condition");
                                                    newCondition1.SetAttribute("attribute", "dg_division");
                                                    newCondition1.SetAttribute("operator", "in");
                                                    for (int i = 0; i < numbers.Length; i++)
                                                    {
                                                        XmlElement valueElement2 = xmlDoc.CreateElement("value");
                                                        valueElement2.InnerText = numbers[i].ToString();
                                                        newCondition1.AppendChild(valueElement2);
                                                    }
                                                    andFilter.AppendChild(newCondition1);
                                                    orFilter.AppendChild(andFilter);


                                                    filterNode.AppendChild(orFilter);
                                                }
                                                string updatedFetchXml = xmlDoc.OuterXml;
                                                context.InputParameters["Query"] = new FetchExpression(updatedFetchXml);
                                            }
                                        }
                                    }

                                }
                            }
                        }
                    }
                }

            }
            catch(Exception ex)
            {
                throw new InvalidPluginExecutionException(ex.Message);
            }
        }
    }
}
