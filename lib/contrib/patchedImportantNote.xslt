<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="text" indent="yes"/>
  <xsl:template match="/patched_build">
THIS IS A LFS RELEASE WITH RESTRICTIONS. THIS LFS RELEASE IS PATCHED AND CAN NOT BE REPRODUCED!

This LFS Release uses the following LFS Builds:
<xsl:for-each select="build">
 <xsl:value-of select="@type" /> : <xsl:value-of select="node()" /> 
 <xsl:text>&#xa;</xsl:text>
</xsl:for-each> 

    <xsl:value-of select="importantNote/node()" />
  </xsl:template>
</xsl:stylesheet>
