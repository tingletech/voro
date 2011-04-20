<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:cdlpath="http://www.cdlib.org/path/"
  version="1.0"
>

<xsl:template match='*|@*'>
        <xsl:copy>
                <xsl:apply-templates select='@*|node()'/>
        </xsl:copy>
</xsl:template>

<xsl:template match="/">
   <xsl:apply-templates/>
</xsl:template>

<xsl:template match="repository">
<root>
<xsl:attribute name="cdlpath:parent">
	<xsl:value-of select="@poi"/>
</xsl:attribute>
<xsl:if test="parent/@poi">
	<xsl:attribute name="cdlpath:grandparent">
		<xsl:value-of select="parent/@poi"/>
	</xsl:attribute>
</xsl:if>
</root>
</xsl:template>

</xsl:stylesheet>
