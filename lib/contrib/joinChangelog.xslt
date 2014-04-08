<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:param name="file" select="file"/>

    <xsl:output method="xml" indent="yes"/>

    <xsl:template match="/log">
        <xsl:copy>
            <xsl:apply-templates select="logentry"/>
            <xsl:apply-templates select="document($file)/*/logentry"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="@* | node()">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>
