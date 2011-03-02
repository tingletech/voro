<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:xlink="http://www.w3.org/TR/xlink"
  xmlns="http://www.loc.gov/METS/"
                                     version="1.0">
<xsl:param name="noindex"/>
                     <xsl:output method="xml" omit-xml-declaration="yes"/>

<!--
	200603 update of label creation logic
	bct 200402 update of 2002 era xslt
	bct 200405 getting ready for release?
  -->

<!-- xsl:include href="institution-ark2url.xsl"/ -->

<!-- this template matches everything, leaving it marked up 
<xsl:template match='*|@*'>
        <xsl:copy>
                <xsl:apply-templates select='@*|node()'/>
        </xsl:copy>
</xsl:template> 

however (see http://www.dpawson.co.uk/xsl/sect2/N5536.html#d163e573 )
since this template does a copy; the namespace from the input
tree gets copied to the output tree.  


-->
<!-- this template matches everything, leaving it marked up,
     changing the namespace  -->

<xsl:template match="*" xmlns="http://www.loc.gov/EAD/">
<xsl:element name="{name()}">
<xsl:for-each select="@*">
<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
</xsl:for-each>
<xsl:apply-templates/>
</xsl:element>
</xsl:template>


<xsl:template match="/">
<!-- xsl:message>hey:|<xsl:value-of select="$noindex"/>|</xsl:message -->
   <xsl:apply-templates select="super | c" mode="first" />
</xsl:template>

<!-- components supordinate to the Finding Aid have a premets file
     with one c root node -->
<xsl:template match="c" mode="first">
<xsl:variable name="noindex-bit">
 <xsl:choose>
 <xsl:when test="$noindex">?noindex=true</xsl:when>
 <xsl:otherwise/>
 </xsl:choose>
</xsl:variable>
<xsl:variable name="label">
 <xsl:choose>
   <xsl:when test="did/unittitle">
	<xsl:value-of select="did/unittitle"/>
   </xsl:when>
   <xsl:when test="series/unittitle[position() = last()]">
	<xsl:value-of select="series/unittitle[position() = last()]"/>
   </xsl:when>
   <xsl:otherwise>
<xsl:text>[no title]</xsl:text>
   </xsl:otherwise>
 </xsl:choose>
</xsl:variable>
<mets xmlns:xlink="http://www.w3.org/TR/xlink" 
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
xsi:schemaLocation="http://www.loc.gov/METS/ http://www.loc.gov/standards/mets/mets.xsd http://www.loc.gov/EAD/ http://findaid.oac.cdlib.org/mets/profiles/2002/OAC-extracted-image/oac-ead.xsd http://ark.cdlib.org/schemas/appqualifieddc/ http://ark.cdlib.org/schemas/appqualifieddc/appqualifieddc.xsd"
OBJID="{@poi}" LABEL="{$label}" TYPE="image" PROFILE="http://ark.cdlib.org/ark:/13030/kt3q2nb7vz{$noindex-bit}">

<metsHdr>
                
<agent ROLE="EDITOR" TYPE="ORGANIZATION">
<name>California Digital Library</name>
<note>record extacted from EAD finding aid</note>
</agent>
        </metsHdr>
<dmdSec ID="dsc">
	<mdWrap MDTYPE="EAD">
	<xmlData>
		<xsl:apply-templates select = "."/>
	</xmlData>
	</mdWrap>
</dmdSec>
<dmdSec ID="ead">
	<mdRef LOCTYPE="URL" MDTYPE="EAD" LABEL="{series/unittitle[1]}" xlink:href="http://www.oac.cdlib.org/findaid/{@parent}"/>
</dmdSec>
<dmdSec ID="repo">
	<mdWrap MIMETYPE="text/xml" MDTYPE="DC" LABEL="Repository">
         <xmlData>
            <cdl:qualifieddc xmlns:cdl="http://ark.cdlib.org/schemas/appqualifieddc/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dc="http://purl.org/dc/elements/1.1/">
				<dc:title><xsl:value-of select="//repository/corpname"/></dc:title>
				<dc:identifier><xsl:value-of select="repository/@poi"/></dc:identifier>
				<dc:identifier>
					<!-- xsl:call-template name="institution-ark2url">
					<xsl:with-param name="ark"><xsl:value-of select="repository/@poi"/></xsl:with-param>
					</xsl:call-template -->
				</dc:identifier>
		   	</cdl:qualifieddc>
		</xmlData>
	</mdWrap>
</dmdSec>
<xsl:call-template name="map"/>
</mets>
</xsl:template>

<xsl:template match="daogrp | dao | daoloc">
</xsl:template>

<xsl:template name="map">
<xsl:variable name="label">
 <xsl:choose>
   <xsl:when test="did/unittitle">
	<xsl:value-of select="did/unittitle"/>
   </xsl:when>
   <xsl:when test="series/unittitle[position() = last()]">
	<xsl:value-of select="series/unittitle[position() = last()]"/>
   </xsl:when>
   <xsl:otherwise>
<xsl:text>[no title]</xsl:text>
   </xsl:otherwise>
 </xsl:choose>
</xsl:variable>
<fileSec><fileGrp>
<xsl:for-each select="did/daogrp/daoloc">
<file ID="{@role}"><FLocat LOCTYPE="URL" xlink:href="{@href}" xlink:role="{@role}"/></file>	
</xsl:for-each>
<xsl:if test="did/dao">
<file ID="dao"><FLocat LOCTYPE="URL" xlink:href="{did/dao/@href}" /></file>
</xsl:if>
</fileGrp></fileSec>
<structMap>
<div LABEL="{$label}">
<xsl:for-each select="did/daogrp/daoloc">
<div LABEL="{@role}"><fptr FILEID="{@role}"/></div>
</xsl:for-each>
<xsl:if test="did/dao">
<div LABEL="Digital Archival Object"><fptr FILEID="dao"/></div>
</xsl:if>
</div>
</structMap>
</xsl:template>

<xsl:template name="ead-map">
<fileSec><fileGrp>
<file ID="dlxs"><FLocat LOCTYPE="URL" xlink:href="http://findaid.oac.cdlib.org/findaid/{@poi}"/></file>	
<file ID="ead"><FLocat LOCTYPE="URL" xlink:href="http://www.oac.cdlib.org/sgml/{@cdlpath}.sgm"/></file>	
<file ID="dynaweb"><FLocat LOCTYPE="URL" xlink:href="http://www.oac.cdlib.org/dynaweb/ead/{@cdlpath}"/></file>	
</fileGrp></fileSec>
<structMap>
<div LABEL="EAD Finding Aid">
<div LABEL="DLXS"><fptr FILEID="dlxs"/></div>
<div LABEL="SGML"><fptr FILEID="ead"/></div>
<div LABEL="View in Dynaweb"><fptr FILEID="dynaweb"/></div>
</div>
</structMap>
</xsl:template>


<xsl:template match="super" mode="first">
<xsl:variable name="noindex-bit">
 <xsl:choose>
 <xsl:when test="$noindex">?noindex=true</xsl:when>
 <xsl:otherwise/>
 </xsl:choose>
</xsl:variable>
<!-- <xsl:processing-instruction name="xml-stylesheet">type=&quot;text/xsl&quot; href=&quot;../xslt/OAC-collection.xslt&quot;</xsl:processing-instruction> -->
<mets 
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:schemaLocation="http://www.loc.gov/METS/ http://www.loc.gov/standards/mets/mets.xsd http://www.loc.gov/EAD/ http://findaid.oac.cdlib.org/mets/profiles/2002/OAC-extracted-image/oac-ead.xsd"
OBJID="{@poi}" LABEL="{@cdltitle}" TYPE="archival collection" PROFILE="http://ark.cdlib.org/ark:/13030/kt0t1nb6x7{$noindex-bit}">

<metsHdr>

<agent ROLE="EDITOR" TYPE="ORGANIZATION">
<name>California Digital Library</name>
<note>record for an EAD Finding Aid</note>
</agent>
<altRecordID TYPE="SGML Catalog"><xsl:value-of select="@eadid"/>
</altRecordID>
<altRecordID TYPE="CDL path">http://oac.cdlib.org/institutions/<xsl:value-of select="@cdlpath"/>
</altRecordID>
<xsl:if test="@cdlgp">
<altRecordID TYPE="CDL path">http://oac.cdlib.org/institutions/<xsl:value-of select="@cdlgp"/>
</altRecordID>
</xsl:if>
        </metsHdr>

<dmdSec ID="dsc">
<mdWrap MDTYPE="EAD">
<xmlData>
<NTITLE xmlns="http://www.cdlib.org/"><xsl:value-of select="@ntitle"/></NTITLE>
<xsl:apply-templates select="c"/>
</xmlData>
</mdWrap>
</dmdSec>
<xsl:call-template name="ead-map"/>

<behaviorSec>
	<behavior ID="disp1" STRUCTID="top" BTYPE="display" LABEL="Display Behavior">
	<interfaceDef LABEL="EAD Display Definition" LOCTYPE="URL" 
	xlink:href="http://texts.cdlib.org/dynaxml/profiles/display/eadDisplayDef.txt"/>
	<mechanism LABEL="EAD Display Mechanism" LOCTYPE="URN" 
	xlink:href="http://texts.cdlib.org/dynaxml/profiles/display/eadDisplayMech.xml"/>
</behavior>

   <behavior ID="auth1" STRUCTID="top" BTYPE="authentication" LABEL="Authentication Behavior">
	<interfaceDef LABEL="General Public Authentication Definition" 
	LOCTYPE="URL" 
	xlink:href="http://texts.cdlib.org/dynaxml/profiles/display/publicAuthDef.txt"/>
	<mechanism LABEL="General Public Authentication Mechanism" LOCTYPE="URL" 	xlink:href="http://texts.cdlib.org/dynaxml/profiles/authentication/publicAuthMech.xml"/>
	</behavior>
</behaviorSec>

</mets>
</xsl:template>

<xsl:template match="c">
<c> 
<xsl:for-each select="@*">
<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
</xsl:for-each>
<xsl:attribute name="xmlns">http://www.loc.gov/EAD/</xsl:attribute>
<xsl:apply-templates/>
</c>
</xsl:template>


</xsl:stylesheet>
