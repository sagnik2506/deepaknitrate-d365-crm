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
    public class MasterApproval : IPlugin
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
                    tracingService.Trace("!");
                    string fetchXml = string.Empty;
                    if (context.InputParameters["Query"] is QueryExpression)
                    {
                        QueryExpression query = (QueryExpression)context.InputParameters["Query"];
                        var qeToFetchXmlRequest = new QueryExpressionToFetchXmlRequest
                        {
                            Query = query
                        };
                        var qeToFetchXmlResponse = (QueryExpressionToFetchXmlResponse)service.Execute(qeToFetchXmlRequest);
                        tracingService.Trace(qeToFetchXmlResponse.FetchXml.ToString());
                        fetchXml = qeToFetchXmlResponse.FetchXml;
                        tracingService.Trace(fetchXml);
                    }
                    else if (context.InputParameters["Query"] is FetchExpression)
                    {
                        FetchExpression fetch = context.InputParameters["Query"] as FetchExpression;
                        fetchXml = fetch.Query;
                        tracingService.Trace(fetchXml);
                    }
                    tracingService.Trace("2");
                    if (fetchXml != null && fetchXml != string.Empty)
                    {
                        XmlDocument xmlDoc = new XmlDocument();
                        xmlDoc.LoadXml(fetchXml);
                        tracingService.Trace("3");
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
                        tracingService.Trace("4");
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
                                            bool price = false;
                                            XmlNodeList linkEntities = xmlDoc.GetElementsByTagName("link-entity");
                                            foreach (XmlNode linkentity in linkEntities)
                                            {
                                                string name = linkentity.Attributes["name"]?.Value;
                                                if (name == "dg_approvalmatrix")
                                                {
                                                    price = true;
                                                    XmlNode filterNode = linkentity.SelectSingleNode("filter");
                                                    if (filterNode == null)
                                                    {
                                                        filterNode = xmlDoc.CreateElement("filter");
                                                        XmlAttribute typeAttr = xmlDoc.CreateAttribute("type");
                                                        typeAttr.Value = "and";
                                                        filterNode.Attributes.Append(typeAttr);

                                                        linkentity.AppendChild(filterNode);
                                                    }
                                                    XmlElement newCondition = xmlDoc.CreateElement("condition");
                                                    newCondition.SetAttribute("attribute", "dg_salesorganization");
                                                    newCondition.SetAttribute("operator", "ne");
                                                    newCondition.SetAttribute("value", "1000");
                                                    XmlElement newCondition1 = xmlDoc.CreateElement("condition");
                                                    newCondition1.SetAttribute("attribute", "dg_salesorganization");
                                                    newCondition1.SetAttribute("operator", "ne");
                                                    newCondition1.SetAttribute("value", "3000");
                                                    filterNode.AppendChild(newCondition);
                                                    filterNode.AppendChild(newCondition1);
                                                    break;
                                                }
                                            }
                                            if (price == false)
                                            {
                                                XmlNode entityNode = xmlDoc.SelectSingleNode("//entity");
                                                if (entityNode != null)
                                                {
                                                    XmlElement linkEntity = xmlDoc.CreateElement("link-entity");
                                                    linkEntity.SetAttribute("name", "dg_approvalmatrix");
                                                    linkEntity.SetAttribute("from", "dg_approvalmatrixid");
                                                    linkEntity.SetAttribute("to", "dg_approvalmatrix");
                                                    linkEntity.SetAttribute("link-type", "inner");
                                                    linkEntity.SetAttribute("alias", "ac");

                                                    XmlElement filter = xmlDoc.CreateElement("filter");
                                                    filter.SetAttribute("type", "and");


                                                    XmlElement condition = xmlDoc.CreateElement("condition");
                                                    condition.SetAttribute("attribute", "dg_salesorganization");
                                                    condition.SetAttribute("operator", "ne");
                                                    condition.SetAttribute("value", "1000");
                                                    XmlElement condition1 = xmlDoc.CreateElement("condition");
                                                    condition1.SetAttribute("attribute", "dg_salesorganization");
                                                    condition1.SetAttribute("operator", "ne");
                                                    condition1.SetAttribute("value", "3000");
                                                    filter.AppendChild(condition1);
                                                    filter.AppendChild(condition);
                                                    linkEntity.AppendChild(filter);

                                                    entityNode.AppendChild(linkEntity);
                                                }
                                            }

                                            string updatedFetchXml = xmlDoc.OuterXml;
                                            context.InputParameters["Query"] = new FetchExpression(updatedFetchXml);

                                        }
                                        else if (SalesOrg != null && SalesOrg.Value == 1000)
                                        {
                                            bool price = false;
                                            XmlNodeList linkEntities = xmlDoc.GetElementsByTagName("link-entity");
                                            foreach (XmlNode linkentity in linkEntities)
                                            {
                                                string name = linkentity.Attributes["name"]?.Value;
                                                if (name == "dg_approvalmatrix")
                                                {
                                                    price = true;
                                                    XmlNode filterNode = linkentity.SelectSingleNode("filter");
                                                    if (filterNode == null)
                                                    {
                                                        filterNode = xmlDoc.CreateElement("filter");
                                                        XmlAttribute typeAttr = xmlDoc.CreateAttribute("type");
                                                        typeAttr.Value = "and";
                                                        filterNode.Attributes.Append(typeAttr);

                                                        linkentity.AppendChild(filterNode);
                                                    }
                                                    XmlElement newCondition = xmlDoc.CreateElement("condition");
                                                    newCondition.SetAttribute("attribute", "dg_salesorganization");
                                                    newCondition.SetAttribute("operator", "eq");
                                                    newCondition.SetAttribute("value", SalesOrg.Value.ToString());
                                                    filterNode.AppendChild(newCondition);
                                                    #region Add Divsion

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
                                                    #endregion
                                                    break;
                                                }
                                            }
                                            if (price == false)
                                            {
                                                XmlNode entityNode = xmlDoc.SelectSingleNode("//entity");
                                                if (entityNode != null)
                                                {
                                                    XmlElement linkEntity = xmlDoc.CreateElement("link-entity");
                                                    linkEntity.SetAttribute("name", "dg_approvalmatrix");
                                                    linkEntity.SetAttribute("from", "dg_approvalmatrixid");
                                                    linkEntity.SetAttribute("to", "dg_approvalmatrix");
                                                    linkEntity.SetAttribute("link-type", "inner");
                                                    linkEntity.SetAttribute("alias", "ac");

                                                    XmlElement filter = xmlDoc.CreateElement("filter");
                                                    filter.SetAttribute("type", "and");


                                                    XmlElement condition = xmlDoc.CreateElement("condition");
                                                    condition.SetAttribute("attribute", "dg_salesorganization");
                                                    condition.SetAttribute("operator", "eq");
                                                    condition.SetAttribute("value", SalesOrg.Value.ToString());

                                                    filter.AppendChild(condition);

                                                    #region Adding Division
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
                                                            filter.AppendChild(newCondition1);
                                                        }
                                                        else if (bi == false && fs == true && pp == false)
                                                        {
                                                            newCondition1.SetAttribute("operator", "eq");
                                                            newCondition1.SetAttribute("value", "40");
                                                            filter.AppendChild(newCondition1);
                                                        }
                                                        else if (bi == false && fs == false && pp == true)
                                                        {
                                                            newCondition1.SetAttribute("operator", "eq");
                                                            newCondition1.SetAttribute("value", "50");
                                                            filter.AppendChild(newCondition1);
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
                                                            filter.AppendChild(newCondition1);
                                                        }
                                                    }
                                                    #endregion
                                                    linkEntity.AppendChild(filter);

                                                    entityNode.AppendChild(linkEntity);
                                                }
                                            }

                                            string updatedFetchXml = xmlDoc.OuterXml;
                                            context.InputParameters["Query"] = new FetchExpression(updatedFetchXml);

                                        }
                                        else if (SalesOrg != null && SalesOrg.Value == 3000)
                                        {
                                            bool price = false;
                                            XmlNodeList linkEntities = xmlDoc.GetElementsByTagName("link-entity");
                                            foreach (XmlNode linkentity in linkEntities)
                                            {
                                                string name = linkentity.Attributes["name"]?.Value;
                                                if (name == "dg_approvalmatrix")
                                                {
                                                    price = true;
                                                    XmlNode filterNode = linkentity.SelectSingleNode("filter");
                                                    if (filterNode == null)
                                                    {
                                                        filterNode = xmlDoc.CreateElement("filter");
                                                        XmlAttribute typeAttr = xmlDoc.CreateAttribute("type");
                                                        typeAttr.Value = "and";
                                                        filterNode.Attributes.Append(typeAttr);

                                                        linkentity.AppendChild(filterNode);
                                                    }
                                                    XmlElement newCondition = xmlDoc.CreateElement("condition");
                                                    newCondition.SetAttribute("attribute", "dg_salesorganization");
                                                    newCondition.SetAttribute("operator", "eq");
                                                    newCondition.SetAttribute("value", SalesOrg.Value.ToString());
                                                    filterNode.AppendChild(newCondition);
                                                    #region Add Divsion

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
                                                    #endregion
                                                    break;
                                                }
                                            }
                                            if (price == false)
                                            {
                                                XmlNode entityNode = xmlDoc.SelectSingleNode("//entity");
                                                if (entityNode != null)
                                                {
                                                    XmlElement linkEntity = xmlDoc.CreateElement("link-entity");
                                                    linkEntity.SetAttribute("name", "dg_approvalmatrix");
                                                    linkEntity.SetAttribute("from", "dg_approvalmatrixid");
                                                    linkEntity.SetAttribute("to", "dg_approvalmatrix");
                                                    linkEntity.SetAttribute("link-type", "inner");
                                                    linkEntity.SetAttribute("alias", "ac");

                                                    XmlElement filter = xmlDoc.CreateElement("filter");
                                                    filter.SetAttribute("type", "and");


                                                    XmlElement condition = xmlDoc.CreateElement("condition");
                                                    condition.SetAttribute("attribute", "dg_salesorganization");
                                                    condition.SetAttribute("operator", "eq");
                                                    condition.SetAttribute("value", SalesOrg.Value.ToString());

                                                    filter.AppendChild(condition);

                                                    #region Adding Division
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
                                                        filter.AppendChild(newCondition1);

                                                    }
                                                    #endregion
                                                    linkEntity.AppendChild(filter);

                                                    entityNode.AppendChild(linkEntity);
                                                }
                                            }

                                            string updatedFetchXml = xmlDoc.OuterXml;
                                            context.InputParameters["Query"] = new FetchExpression(updatedFetchXml);

                                        }
                                    }
                                    else if (MultiSalesOrg.Count == 2)
                                    {
                                        int salesOrg1 = 0;
                                        int salesOrg2 = 0;
                                        salesOrg1 = MultiSalesOrg[0].Value;
                                        salesOrg2 = MultiSalesOrg[1].Value;
                                        if ((salesOrg1 == 1000 || salesOrg1 == 3000) && (salesOrg2 == 1000 || salesOrg2 == 3000))
                                        {
                                            bool price = false;
                                            XmlNodeList linkEntities = xmlDoc.GetElementsByTagName("link-entity");
                                            foreach (XmlNode linkentity in linkEntities)
                                            {
                                                string name = linkentity.Attributes["name"]?.Value;
                                                if (name == "dg_approvalmatrix")
                                                {
                                                    price = true;
                                                    XmlNode filterNode = linkentity.SelectSingleNode("filter");
                                                    if (filterNode == null)
                                                    {
                                                        filterNode = xmlDoc.CreateElement("filter");
                                                        XmlAttribute typeAttr = xmlDoc.CreateAttribute("type");
                                                        typeAttr.Value = "and";
                                                        filterNode.Attributes.Append(typeAttr);

                                                        linkentity.AppendChild(filterNode);
                                                    }
                                                    XmlElement newCondition = xmlDoc.CreateElement("condition");
                                                    newCondition.SetAttribute("attribute", "dg_salesorganization");
                                                    newCondition.SetAttribute("operator", "in");
                                                    XmlElement valueElement = xmlDoc.CreateElement("value"); // For Sales Org 1
                                                    valueElement.InnerText = salesOrg1.ToString();
                                                    newCondition.AppendChild(valueElement);
                                                    XmlElement valueElement1 = xmlDoc.CreateElement("value"); // For Sales Org 2
                                                    valueElement1.InnerText = salesOrg2.ToString();
                                                    newCondition.AppendChild(valueElement1);
                                                    filterNode.AppendChild(newCondition);
                                                    #region Add Divsion

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
                                                    #endregion
                                                    break;
                                                }
                                            }
                                            if (price == false)
                                            {
                                                XmlNode entityNode = xmlDoc.SelectSingleNode("//entity");
                                                if (entityNode != null)
                                                {
                                                    XmlElement linkEntity = xmlDoc.CreateElement("link-entity");
                                                    linkEntity.SetAttribute("name", "dg_approvalmatrix");
                                                    linkEntity.SetAttribute("from", "dg_approvalmatrixid");
                                                    linkEntity.SetAttribute("to", "dg_approvalmatrix");
                                                    linkEntity.SetAttribute("link-type", "inner");
                                                    linkEntity.SetAttribute("alias", "ac");

                                                    XmlElement filter = xmlDoc.CreateElement("filter");
                                                    filter.SetAttribute("type", "and");


                                                    XmlElement condition = xmlDoc.CreateElement("condition");
                                                    condition.SetAttribute("attribute", "dg_salesorganization");
                                                    condition.SetAttribute("operator", "in");
                                                    XmlElement valueElement = xmlDoc.CreateElement("value"); // For Sales Org 1
                                                    valueElement.InnerText = salesOrg1.ToString();
                                                    condition.AppendChild(valueElement);
                                                    XmlElement valueElement1 = xmlDoc.CreateElement("value"); // For Sales Org 2
                                                    valueElement1.InnerText = salesOrg2.ToString();
                                                    condition.AppendChild(valueElement1);

                                                    filter.AppendChild(condition);

                                                    #region Adding Division
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
                                                        filter.AppendChild(newCondition1);

                                                    }
                                                    #endregion
                                                    linkEntity.AppendChild(filter);

                                                    entityNode.AppendChild(linkEntity);
                                                }
                                            }

                                            string updatedFetchXml = xmlDoc.OuterXml;
                                            context.InputParameters["Query"] = new FetchExpression(updatedFetchXml);
                                        }

                                        else if ((salesOrg1 == 2000 || salesOrg1 == 3000) && (salesOrg2 == 2000 || salesOrg2 == 3000))
                                        {
                                            bool price = false;
                                            XmlNodeList linkEntities = xmlDoc.GetElementsByTagName("link-entity");
                                            foreach (XmlNode linkentity in linkEntities)
                                            {
                                                string name = linkentity.Attributes["name"]?.Value;
                                                if (name == "dg_approvalmatrix")
                                                {
                                                    price = true;
                                                    XmlNode filterNode = linkentity.SelectSingleNode("filter");
                                                    if (filterNode == null)
                                                    {
                                                        filterNode = xmlDoc.CreateElement("filter");
                                                        XmlAttribute typeAttr = xmlDoc.CreateAttribute("type");
                                                        typeAttr.Value = "and";
                                                        filterNode.Attributes.Append(typeAttr);

                                                        linkentity.AppendChild(filterNode);
                                                    }

                                                    XmlElement orFilter = xmlDoc.CreateElement("filter");
                                                    orFilter.SetAttribute("type", "or");

                                                    XmlElement credit2000 = xmlDoc.CreateElement("condition");
                                                    credit2000.SetAttribute("attribute", "dg_salesorganization");
                                                    credit2000.SetAttribute("operator", "eq");
                                                    credit2000.SetAttribute("value", "2000");
                                                    orFilter.AppendChild(credit2000);

                                                    XmlElement innerAndFilter = xmlDoc.CreateElement("filter");
                                                    innerAndFilter.SetAttribute("type", "and");

                                                    XmlElement credit3000 = xmlDoc.CreateElement("condition");
                                                    credit3000.SetAttribute("attribute", "dg_salesorganization");
                                                    credit3000.SetAttribute("operator", "eq");
                                                    credit3000.SetAttribute("value", "3000");
                                                    innerAndFilter.AppendChild(credit3000);



                                                 
                                                    #region Add Divsion

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
                                                        bool phenolix = true;
                                                        bool byproduct = true;
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
                                                        innerAndFilter.AppendChild(newCondition1);

                                                    }
                                                    orFilter.AppendChild(innerAndFilter);
                                                    filterNode.AppendChild(orFilter);
                                                    #endregion
                                                    break;
                                                }
                                            }
                                            if (price == false)
                                            {
                                                XmlNode entityNode = xmlDoc.SelectSingleNode("//entity");
                                                if (entityNode != null)
                                                {
                                                    XmlElement linkEntity = xmlDoc.CreateElement("link-entity");
                                                    linkEntity.SetAttribute("name", "dg_approvalmatrix");
                                                    linkEntity.SetAttribute("from", "dg_approvalmatrixid");
                                                    linkEntity.SetAttribute("to", "dg_approvalmatrix");
                                                    linkEntity.SetAttribute("link-type", "inner");
                                                    linkEntity.SetAttribute("alias", "ac");

                                                    XmlElement filter = xmlDoc.CreateElement("filter");
                                                    filter.SetAttribute("type", "and");

                                                    XmlElement orFilter = xmlDoc.CreateElement("filter");
                                                    orFilter.SetAttribute("type", "or");

                                                    XmlElement condSegment2000 = xmlDoc.CreateElement("condition");
                                                    condSegment2000.SetAttribute("attribute", "dg_salesorganization");
                                                    condSegment2000.SetAttribute("operator", "eq");
                                                    condSegment2000.SetAttribute("value", "2000");

                                                    orFilter.AppendChild(condSegment2000);

                                                    XmlElement innerAndFilter = xmlDoc.CreateElement("filter");
                                                    innerAndFilter.SetAttribute("type", "and");

                                                    XmlElement condSegment3000 = xmlDoc.CreateElement("condition");
                                                    condSegment3000.SetAttribute("attribute", "dg_salesorganization");
                                                    condSegment3000.SetAttribute("operator", "eq");
                                                    condSegment3000.SetAttribute("value", "3000");
                                                    innerAndFilter.AppendChild(condSegment3000);




                                                  

                                                    #region Adding Division
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
                                                        bool phenolix = true;
                                                        bool byproduct = true;
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
                                                        innerAndFilter.AppendChild(newCondition1);

                                                    }
                                                    orFilter.AppendChild(innerAndFilter);
                                                    filter.AppendChild(orFilter);
                                                    #endregion
                                                    linkEntity.AppendChild(filter);

                                                    entityNode.AppendChild(linkEntity);
                                                }
                                            }

                                            string updatedFetchXml = xmlDoc.OuterXml;
                                            context.InputParameters["Query"] = new FetchExpression(updatedFetchXml);
                                        }
                                    }
                                }
                            }
                            else
                            {
                                context.InputParameters["Query"] = new FetchExpression(fetchXml);
                            }
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
