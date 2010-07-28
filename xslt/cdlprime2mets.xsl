<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:xlink="http://www.w3.org/TR/xlink"
  xmlns="http://www.loc.gov/METS/"
  xmlns:exslt="http://exslt.org/common"
  xmlns:cdlpath="http://www.cdlib.org/path/"
                                     version="1.0">

<xsl:output method="xml" omit-xml-declaration="yes"
standalone="no"
/>

<xsl:template match="/">
        <xsl:apply-templates select="ead" mode="p2"/>
</xsl:template>

<xsl:param name="ark" select="substring-after(/ead/eadheader/eadid/@identifier,'ark:/13030/')"/>

<xsl:param name="doc.path">?docId=<xsl:value-of select="$ark"/></xsl:param>

<xsl:param name="cdlpath"/>

<!-- this template matches everything, leaving it marked up,
     changing the namespace  -->

<xsl:template match="did" xmlns="http://www.loc.gov/EAD/" mode="eadcopy">
<did>
<xsl:apply-templates select="container| dao| daogrp| head| langmaterial| materialspec| note| origination| physloc| repository| unitdate| unitid| unittitle" mode="eadcopy"/>
<abstract>
<xsl:choose>
 <xsl:when test="abstract">
   <xsl:for-each select="abstract/@*">
     <xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
   </xsl:for-each>
	<xsl:apply-templates select="abstract[1]/text()" mode="eadcopy"/>
 </xsl:when>
 <xsl:when test="../scopecontent//p[1]/text()">
	<xsl:apply-templates select="(../scopecontent//p)[1]/text()" mode="eadcopy"/>...
 </xsl:when>
 <xsl:otherwise>
 </xsl:otherwise>
</xsl:choose>
</abstract>
<physdesc>
   <xsl:for-each select="physdesc/@*">
     <xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
   </xsl:for-each>
   <xsl:apply-templates select="physdesc/node()" mode="eadcopy"/>
   <xsl:if test="not(physdesc/extent[@type='dao']) and ( //dao  or //daogrp )">
	<extent type="dao">
	 <xsl:choose>
		<xsl:when test="count(//dao|//daogrp) = 1">
		online items
		</xsl:when>
		<xsl:when test="count(//dao|//daogrp) &gt; 1">
		<xsl:value-of select="count(//dao|//daogrp)"/> items
		</xsl:when>
	 </xsl:choose>
	</extent>
   </xsl:if>
</physdesc>


</did>
</xsl:template>


<xsl:template match="*" xmlns="http://www.loc.gov/EAD/" mode="eadcopy">
<xsl:element name="{name()}">
<xsl:for-each select="@*">
<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
</xsl:for-each>
<xsl:apply-templates mode="eadcopy"/>
</xsl:element>
</xsl:template>

<xsl:template match="archdesc" xmlns="http://www.loc.gov/EAD/" mode="eadcopy">
<c>
<xsl:for-each select="@*">
<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
</xsl:for-each>
<xsl:apply-templates 
	select="accessrestrict| accruals| acqinfo| altformavail| appraisal| arrangement| bibliography| bioghist| controlaccess| custodhist| did | fileplan| note| odd| originalsloc| otherfindaid| phystech| prefercite| processinfo| relatedmaterial| runner| scopecontent| separatedmaterial| userestrict"
	mode="eadcopy"/>
</c>
</xsl:template>


<xsl:template match="ead" mode="p2">
<mets 
xml:space="preserve"
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:schemaLocation="http://www.loc.gov/METS/ http://www.loc.gov/standards/mets/mets.xsd http://www.loc.gov/EAD/ http://findaid.oac.cdlib.org/mets/profiles/2002/OAC-extracted-image/oac-ead.xsd"
OBJID="{eadheader/eadid/@identifier}" 
LABEL="{eadheader/filedesc/titlestmt/titleproper[@type='filing']}" 
TYPE="archival collection" PROFILE="http://ark.cdlib.org/ark:/13030/kt0t1nb6x7">

<metsHdr>

<agent ROLE="EDITOR" TYPE="ORGANIZATION">
<name>California Digital Library</name>
<note>record for an EAD Finding Aid</note>
</agent>
<altRecordID TYPE="SGML Catalog"><xsl:value-of select="eadheader/eadid"/>
</altRecordID>
<altRecordID TYPE="CDL path">http://oac.cdlib.org/institutions/<xsl:value-of select="eadheader/eadid/@cdlpath:parent"/></altRecordID>
<xsl:if test="eadheader/eadid/@cdlpath:grandparent">
<altRecordID TYPE="CDL path">http://oac.cdlib.org/institutions/<xsl:value-of select="eadheader/eadid/@cdlpath:grandparent"/></altRecordID>
</xsl:if>
<altRecordID TYPE="voroFileNameBase"><xsl:value-of select="$cdlpath"/></altRecordID>
        </metsHdr>

<dmdSec ID="dsc">
<mdWrap MDTYPE="EAD">
<xmlData>
<xsl:apply-templates select="archdesc" mode="eadcopy"/>
</xmlData>
</mdWrap>
</dmdSec>

<fileSec>
	<fileGrp>
		<file ID="top">
		<FLocat LOCTYPE="URL" xlink:href="{$doc.path}"/>
		</file>
		<xsl:apply-templates select="archdesc" mode="file"/>
	</fileGrp>
</fileSec>

<structMap>
<div LABEL="{eadheader/filedesc/titlestmt/titleproper[@type='filing']}">
<fptr FILEID="top"/>
   <div>
	<xsl:apply-templates select="archdesc" mode="div"/>
   </div>
</div>
</structMap>

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

<xsl:template match="archdesc" mode="file">
	<xsl:apply-templates select="*[@id]" mode="file"/>
	<xsl:apply-templates select="dsc/*[@id]" mode="file"/>
</xsl:template>

<xsl:template match="archdesc" mode="div">
	<xsl:apply-templates select="*[@id]" mode="div"/>
	<xsl:apply-templates select="dsc/*[@id]" mode="div"/>
</xsl:template>

<xsl:template match="*" mode="div">
<xsl:choose>
  <xsl:when test="head">
<div LABEL="{head}"><fptr FILEID="{@id}"/></div>
<xsl:text>
        </xsl:text>
  </xsl:when>
  <xsl:when test="did/unittitle">
<div LABEL="{did/unittitle}"><fptr FILEID="{@id}"/>

<xsl:apply-templates select="archdesc/*[@id] | c01[@id][@level='series'] | c01[@id][@level='collection'] | c01[@id][@level='recordgrp'] | c01[@id][@level='subseries'] | c02[@id][@level='series'] | c02[@id][@level='collection'] | c02[@id][@level='recordgrp'] | c02[@id][@level='subseries']" mode="div"/>
</div>
  </xsl:when>
  <xsl:otherwise/>
 </xsl:choose>
</xsl:template>

<xsl:template match="*" mode="file">
<xsl:choose>
  <xsl:when test="head">
	<file ID="{@id}">
		<FLocat LOCTYPE="URL" xlink:href="{$doc.path}&#038;chunk.id={@id}"/>
	</file>
<xsl:text>
        </xsl:text>
  </xsl:when>
  <xsl:when test="did/unittitle">
	<file ID="{@id}"><FLocat LOCTYPE="URL" xlink:href="{$doc.path}&#038;chunk.id={@id}"/></file>
<xsl:apply-templates select="archdesc/*[@id] | c01[@id][@level='series'] | c01[@id][@level='collection'] | c01[@id][@level='recordgrp'] | c01[@id][@level='subseries'] | c02[@id][@level='series'] | c02[@id][@level='collection'] | c02[@id][@level='recordgrp'] | c02[@id][@level='subseries']" mode="file"/>
  </xsl:when>
  <xsl:otherwise/>
 </xsl:choose>
</xsl:template>


</xsl:stylesheet>
