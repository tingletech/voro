<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  version="1.0"
>
<!-- xsl:output encoding="iso-8859-1"/ -->
<xsl:param name="cdlpath"/>
<!-- this template matches everything, leaving it marked up -->

<xsl:template match='*|@*'>
        <xsl:copy>
                <xsl:apply-templates select='@*|node()'/>
        </xsl:copy>
</xsl:template>

<xsl:template match="/">
   <xsl:apply-templates/>
</xsl:template>

<xsl:template match="ead">
	<ead>
   <xsl:apply-templates/>
	</ead>
</xsl:template>


<!-- xsl:template match=" tspec | tspec/* | thead | drow">
</xsl:template -->

<xsl:template match="archdesc | archdesc/* | c| c01| c02| c03| c04| c05| c06| c07| c08| c09| c10| c11| c12"> 
<xsl:element name="{name()}">
<xsl:for-each select="@*">
<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
</xsl:for-each>
<xsl:if test="not(@id)">
<xsl:attribute name="id">
	<xsl:value-of select="name()"/>-<xsl:number count="*" level="multiple"/>
</xsl:attribute>
</xsl:if>
<!-- xsl:if test="drow">
	<xsl:for-each select="drow">
		<did>
   			<xsl:call-template name="didkid"/>
		</did>
   		<xsl:call-template name="didsib"/>
	</xsl:for-each>
</xsl:if -->
	<xsl:apply-templates/>
</xsl:element>
</xsl:template>


<!-- xsl:template name="didkid">
	<xsl:apply-templates select="dentry/unittitle | dentry/unitdate | dentry/unitid |
		dentry/abstract | dentry/container | dentry/dao | dentry/daogrp | dentry/note | dentry/origination | 
		dentry/physdesc | dentry/physloc | dentry/repository"/>
</xsl:template>

<xsl:template name="didsib">
	<xsl:apply-templates select="dentry/add | dentry/admininfo | dentry/arrangement | dentry/bioghist |
		dentry/controlaccess | dentry/odd | dentry/organization | dentry/scopecontent"/>
</xsl:template -->

<xsl:template match="daoloc">
<daoloc>
<xsl:for-each select="@*">
<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
</xsl:for-each>
<xsl:if test="not(@href) and unparsed-entity-uri(@entityref)">
<xsl:attribute name="href"><xsl:value-of select="unparsed-entity-uri(@entityref)"/></xsl:attribute>
</xsl:if>
</daoloc>
</xsl:template>

<!-- <xsl:template match="extref"> -->
<xsl:template match="archref">
<archref>
<xsl:for-each select="@*">
<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
</xsl:for-each>
<xsl:if test="not(@href) and unparsed-entity-uri(@entityref)">
<xsl:attribute name="href"><xsl:value-of select="unparsed-entity-uri(@entityref)"/></xsl:attribute>
</xsl:if>
<xsl:apply-templates/>
</archref>
</xsl:template>

<xsl:template match="extref">
<extref>
<xsl:for-each select="@*">
<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
</xsl:for-each>
<xsl:if test="not(@href) and unparsed-entity-uri(@entityref)">
<!-- <xsl:if test="not(@href)">
<xsl:if test="unparsed-entity-uri(@entityref)"> -->
<xsl:attribute name="href"><xsl:value-of select="unparsed-entity-uri(@entityref)"/></xsl:attribute>
</xsl:if>
<!-- </xsl:if> -->
<xsl:apply-templates/>
</extref>
</xsl:template>


<xsl:template match="dao">
<dao>
<xsl:for-each select="@*">
<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
</xsl:for-each>
<xsl:if test="not(@href) and unparsed-entity-uri(@entityref)">
<!-- <xsl:if test="not(@href)">
<xsl:if test="unparsed-entity-uri(@entityref)"> -->
<xsl:attribute name="href"><xsl:value-of select="unparsed-entity-uri(@entityref)"/></xsl:attribute>
</xsl:if>
<xsl:apply-templates/>
</dao>
</xsl:template>

<!-- xsl:template match="list">
<xsl:choose>
<xsl:when test="@type">
<list type="{@type}"><xsl:apply-templates/></list>
</xsl:when><xsl:otherwise>
<list><xsl:apply-templates/></list>
</xsl:otherwise>
</xsl:choose>
</xsl:template -->

</xsl:stylesheet>
