<xsl:stylesheet version="2.0"
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.loc.gov/METS/"
	xmlns:mets="http://www.loc.gov/METS/"
	xmlns:xlink="http://www.w3.org/1999/xlink"
	xmlns:mods="http://www.loc.gov/mods/v3"
	xmlns:rts="http://cosimo.stanford.edu/sdr/metsrights/"
>

<xsl:param name="voroOut" select="string('no')"/>

<xsl:variable name="source-file">
 <xsl:choose>
   <xsl:when test="$voroOut = 'no'">
	<xsl:value-of select="replace(base-uri(/),'([^/].*)\.mets\.xml','$1.dc.xml')"/>
   </xsl:when>
   <xsl:otherwise>
	<xsl:value-of select="replace(replace(base-uri(/),'([^/].*)\.mets\.xml','$1.dc.xml'),'/texts/','/texts-dc/')"/>
   </xsl:otherwise>
 </xsl:choose>
</xsl:variable>
<xsl:variable name="source" 
	select="document($source-file)"/>

<!-- identity -->
<xsl:template match="@*|node()">
  <xsl:copy copy-namespaces="yes">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:copy>
</xsl:template>

<xsl:template match="mets:mets">
<mets>
  <xsl:apply-templates select="@*"/>
  <xsl:apply-templates select="mets:metsHdr"/>
  <xsl:apply-templates select="mets:dmdSec"/>
  <xsl:apply-templates select="mets:fileSec"/>
  <xsl:apply-templates select="mets:structMap"/>
  <xsl:apply-templates select="mets:structLink"/>
  <xsl:apply-templates select="mets:behaviorSec"/>
</mets>
</xsl:template>

<xsl:template match="@PROFILE[parent::mets:mets]">
  <xsl:attribute name="PROFILE" select="'http://ark.cdlib.org/ark:/13030/kt4199q42g'"/>
 </xsl:template>

<xsl:template match="mets:dmdSec[1]">
<dmdSec>
  <mdWrap>
   <xmlData>
	<xsl:copy-of select="$source"/>
   </xmlData>
  </mdWrap>
</dmdSec>
<dmdSec>
  <xsl:apply-templates select="@*|node()"/>
</dmdSec>
</xsl:template>

</xsl:stylesheet>
