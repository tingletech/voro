<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:mets="http://www.loc.gov/METS/"
  xmlns="http://www.loc.gov/METS/"
  xmlns:mix="http://www.loc.gov/mix/"
  xmlns:moa2="http://sunsite.berkeley.edu/MOA2/" 
  xmlns:cdl="http://www.cdlib.org/"
  xmlns:mods="http://www.loc.gov/mods/v3"
  xmlns:rts="http://cosimo.stanford.edu/sdr/metsrights/"
  version="1.0"
>

<xsl:template match="mods:mods[not(preceding::mods:mods)]">
<mods:mods>
  <xsl:for-each select="@*">
  <xsl:copy copy-namespaces="yes">
    <xsl:apply-templates select="."/>
  </xsl:copy>
  </xsl:for-each>

<xsl:apply-templates select="mods:titleInfo"/>
<xsl:apply-templates select="mods:name"/>
<xsl:apply-templates select="mods:typeOfResource"/>
<xsl:apply-templates select="mods:genre"/>
<xsl:apply-templates select="mods:originInfo"/>
<xsl:apply-templates select="mods:language"/>
<xsl:apply-templates select="mods:physicalDescription"/>
<xsl:apply-templates select="mods:abstract"/>
<xsl:apply-templates select="mods:tableOfContents"/>
<xsl:apply-templates select="mods:targetAudience"/>
<xsl:apply-templates select="mods:note"/>
<xsl:apply-templates select="mods:subject"/>
<xsl:apply-templates select="mods:classification"/>
<xsl:apply-templates select="mods:relatedItem"/>
<xsl:apply-templates select="mods:identifier"/>
<xsl:apply-templates select="mods:location"/>
<xsl:variable name="rMD" select="/mets:mets/mets:amdSec/mets:rightsMD[1]/mets:mdWrap/mets:xmlData/rts:RightsDeclarationMD"/>
<xsl:apply-templates select="($rMD)/rts:Context/rts:Constraints/rts:ConstraintDescription" mode="buff"/>
<xsl:apply-templates select="($rMD)/rts:RightsHolder/rts:RightsHolderName" mode="buff"/>
<xsl:apply-templates select="($rMD)/rts:RightsHolder/rts:RightsHolderComments" mode="buff"/>
<xsl:apply-templates select="($rMD)/rts:RightsHolder/rts:RightsHolderContact" mode="buff"/>
<xsl:apply-templates select="mods:accessCondition"/>
<xsl:apply-templates select="mods:part"/>
<xsl:apply-templates select="mods:extension"/>
<xsl:apply-templates select="mods:recordInfo"/>
</mods:mods>
</xsl:template>

<xsl:template match="moa2:Rights[moa2:Owner]">
<mods:accessCondition displayLabel="Copyright Owner">
      <xsl:value-of select="moa2:Owner"/>
</mods:accessCondition><xsl:text>
</xsl:text>
</xsl:template>

<xsl:template match="rts:ConstraintDescription" mode="buff">
<mods:accessCondition displayLabel="Copyright Note">
        <xsl:value-of select="."/>
</mods:accessCondition><xsl:text>
</xsl:text>
</xsl:template>

<xsl:template match="rts:RightsHolderName" mode="buff">
<mods:accessCondition displayLabel="Copyright Owner">
        <xsl:value-of select="."/>
</mods:accessCondition><xsl:text>
</xsl:text>
</xsl:template>

<xsl:template match="rts:RightsHolderComments" mode="buff">
<mods:accessCondition displayLabel="Copyright Owner Note">
        <xsl:value-of select="."/>
</mods:accessCondition><xsl:text>
</xsl:text>
</xsl:template>

<xsl:template match="rts:RightsHolderContact" mode="buff">
<mods:accessCondition displayLabel="Copyright Contact">
        <xsl:value-of select="."/>
</mods:accessCondition><xsl:text>
</xsl:text>
</xsl:template>

</xsl:stylesheet>
