<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
xmlns:cdlpath="http://www.cdlib.org/path/"
version="1.0">
  <xsl:param name="cdlpath"/>
  <xsl:template match="/">
    <eadobjs>
      <super poi="{/ead/eadheader/eadid/@identifier}" cdlpath="{/ead/eadheader/eadid/@cdlpath:parent}" cdltitle="{/ead/eadheader//titleproper[@type='filing']}" >
        <xsl:attribute name="eadid">
          <xsl:value-of select="/ead/eadheader/eadid/@identifier"/>
        </xsl:attribute>
	<xsl:if test="/ead/eadheader/eadid/@cdlpath:grandparent">
	  <xsl:attribute name="cdlgp">
		<xsl:value-of select="/ead/eadheader/eadid/@cdlpath:grandparent"/>
          </xsl:attribute>
	</xsl:if>
        <xsl:apply-templates select="ead/archdesc" mode="a"/>
      </super>
      <sub>
        <xsl:apply-templates select="/ead/archdesc//dao[starts-with(@role,'http://oac.cdlib.org/arcrole/define')]
| /ead/archdesc//dao[starts-with(@role,'http://oac.cdlib.org/arcrole/define')]
| /ead/archdesc//daogrp[not(starts-with(@role,'http://oac.cdlib.org/arcrole/link'))]" mode="a"/>
      </sub>
    </eadobjs>
  </xsl:template>
  <xsl:template match="archdesc" mode="a">
    <c from="archdesc">
      <xsl:for-each select="@*">
        <xsl:attribute name="{name()}">
          <xsl:value-of select="."/>
        </xsl:attribute>
      </xsl:for-each>
      <xsl:apply-templates select="add | admininfo | arrangement | bioghist | controlaccess | dao | daogrp | did |  note | odd | organization | runner | scopecontent"/>
    </c>
  </xsl:template>
  <xsl:template match="dao | daogrp" mode="a">
    <xsl:choose>
<!-- <xsl:when test="name(..) = 'did'">  -->
      <xsl:when test="count(../../did) = 1">
        <c poi="{@poi}" from="{name(../..)}" position="{position()}">
          <xsl:for-each select="../../@*">
            <xsl:attribute name="{name()}">
              <xsl:value-of select="."/>
            </xsl:attribute>
          </xsl:for-each>
          <series>
<xsl:apply-templates select="/ead/CDLPATH" mode="series"/>
            <xsl:apply-templates select="/ead/archdesc/did/unittitle" mode="series"/>
            <xsl:call-template name="series"/>
          </series>
          <xsl:apply-templates select="../../add| ../../admininfo| ../../arrangement| ../../bioghist| ../../controlaccess| ../../did| ../../head| ../../note| ../../odd| ../../organization| ../../scopecontent | ."/>
<xsl:apply-templates select="/ead/archdesc/did/repository[1]"/>
        </c>
      </xsl:when>
      <xsl:when test="count(../../did) &gt; 1">
        <c poi="{@poi}" from="{name(../..)}" position="{position()}"><xsl:for-each select="../../@*"><xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute></xsl:for-each>
<series>
<xsl:apply-templates select="/ead/CDLPATH" mode="series"/>
<xsl:apply-templates select="/ead/archdesc/did/unittitle" mode="series"/><xsl:call-template name="series"/></series>
<!-- <xsl:apply-templates select="../../did[1] | .."/> -->
<xsl:apply-templates select="../../add[1]| ../../admininfo[1]| ../../arrangement| ../../bioghist[1]| ../../controlaccess[1]| ../../did[1]| ../../head[1]| ../../note[1]| ../../odd[1]| ../../organization[1]| ../../scopecontent[1] | .. | ../add | ../admininfo | ../arrangement | ../odd | ../organization |  ../scopecontent"/>
<xsl:apply-templates select="/ead/archdesc/did/repository[1]"/>
</c>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message>Found <xsl:value-of select="name()"/> not in did in <xsl:value-of select="$cdlpath"/></xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
<!-- this template matches everything, leaving it marked up -->
  <xsl:template match="*|@*">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template name="series">
    <xsl:if test="../../../did/unittitle">
      <xsl:for-each select="..">
        <xsl:call-template name="series"/>
      </xsl:for-each>
      <xsl:apply-templates select="../../../did/unittitle" mode="series"/>
    </xsl:if>
  </xsl:template>
  <xsl:template match="unittitle" mode="series">
    <unittitle from="{name(../..)}">
      <xsl:for-each select="../../did/unittitle/@*">
        <xsl:attribute name="{name()}">
          <xsl:value-of select="."/>
        </xsl:attribute>
      </xsl:for-each>
      <xsl:apply-templates/>
    </unittitle>
  </xsl:template>

  <xsl:template match="CDLPATH" mode="series">
<xsl:variable name="href">
    <xsl:choose>
	<xsl:when test="./@type='parent'">http://oac.cdlib.org/institutions/<xsl:value-of select="."/></xsl:when>
	<xsl:when test="./@type='grandparent'">http://oac.cdlib.org/institutions/<xsl:value-of select="."/></xsl:when>
	<xsl:when test="starts-with(.,'http://')"><xsl:value-of select="."/></xsl:when>
	<xsl:otherwise></xsl:otherwise>
    </xsl:choose>
</xsl:variable>
<xsl:if test="$href != ''">
   <extref role="relation" href="{$href}"/>
</xsl:if>
  </xsl:template>

 <xsl:template match="repository">
   <repository poi="{/ead/eadheader/eadid/@cdlpath:parent}">
      <xsl:for-each select="@*">
        <xsl:attribute name="{name()}">
          <xsl:value-of select="."/>
        </xsl:attribute>
	  </xsl:for-each>
	 <xsl:apply-templates/>
   </repository>
</xsl:template>

</xsl:stylesheet>
