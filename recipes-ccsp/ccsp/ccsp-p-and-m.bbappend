FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

require ccsp_common_turris.inc

DEPENDS_append = " utopia curl "

CFLAGS_append = " \
    -I=${includedir}/utctx \
    -I=${includedir}/utapi \
"
LDFLAGS_append =" \
    -lsyscfg \
    -lbreakpadwrapper \
"

LDFLAGS_remove = " \
    -lmoca_mgnt \
"

CFLAGS_remove = "-Werror"

EXTRA_OECONF_append  = " --with-ccsp-arch=arm"

SRC_URI += "file://Get_Device_Mode_impl_for_turris.patch;apply=no"
do_turris_patches() {
    cd ${S}
    if [ ! -e turris_patch_applied ]; then
        bbnote "Applying Get_Device_Mode_impl_for_turris.patch"
        patch -p1 < ${WORKDIR}/Get_Device_Mode_impl_for_turris.patch || echo "ERROR or Patch already applied"
        touch turris_patch_applied
    fi
}

addtask turris_patches after do_unpack before do_compile
do_configure_prepend () {
   #for WanManager support
   #Below lines of code needs to be removed , once (Device.DHCPv4.Client.{i} and Device.DhCPv6,CLient.{i}) the mentioned parameters are permanently removed from TR181-USGv2.XML
    DISTRO_WAN_ENABLED="${@bb.utils.contains('DISTRO_FEATURES','rdkb_wan_manager','true','false',d)}"
if [ $DISTRO_WAN_ENABLED = 'true' ]; then
if [ ! -f ${WORKDIR}/WanManager_XML_UPDATED ]; then
   GREP_WORD=`cat -n ${S}/config-arm/TR181-USGv2.XML  | grep 9536 | cut -d '<' -f2 | cut -d  '>' -f2`
   if [ "$GREP_WORD" = "ClientNumberOfEntries" ]; then
        #for DHCPv4.Client.{i}.
        sed -i '9534s/<parameter>/<!-- <parameter>/g' ${S}/config-arm/TR181-USGv2.XML
        sed -i '9542s/<\/parameter>/<\/parameter>-->/g' ${S}/config-arm/TR181-USGv2.XML
        sed -i '9642s/<object>/<!-- <object>/g' ${S}/config-arm/TR181-USGv2.XML
        sed -i '10058s/<\/object>/<\/object>-->/g' ${S}/config-arm/TR181-USGv2.XML
        #for DHCPv6.Client.{i}.
        sed -i '10832s/<parameter>/<!-- <parameter>/g' ${S}/config-arm/TR181-USGv2.XML
        sed -i '10836s/<\/parameter>/<\/parameter>-->/g' ${S}/config-arm/TR181-USGv2.XML
        sed -i '10839s/<object>/<!-- <object>/g' ${S}/config-arm/TR181-USGv2.XML
        sed -i '11138s/<\/object>/<\/object>-->/g' ${S}/config-arm/TR181-USGv2.XML
   fi
   touch ${WORKDIR}/WanManager_XML_UPDATED
fi
fi
}

do_install_append(){
    # Config files and scripts
    install -m 644 ${S}/config-arm/CcspDmLib.cfg ${D}/usr/ccsp/pam/CcspDmLib.cfg
    install -m 644 ${S}/config-arm/CcspPam.cfg -t ${D}/usr/ccsp/pam
    install -m 644 ${S}/config-arm/TR181-USGv2.XML -t ${D}/usr/ccsp/pam
    install -m 755 ${S}/scripts/email_notification_monitor.sh ${D}/usr/ccsp/pam/email_notification_monitor.sh
    install -m 755 ${S}/arch/intel_usg/boards/arm_shared/scripts/calc_random_time_to_reboot_dev.sh ${D}/usr/ccsp/pam/calc_random_time_to_reboot_dev.sh
    install -m 755 ${S}/arch/intel_usg/boards/arm_shared/scripts/network_response.sh ${D}/usr/ccsp/pam/network_response.sh
    install -m 755 ${S}/arch/intel_usg/boards/arm_shared/scripts/network_response.sh ${D}/etc/network_response.sh
    install -m 755 ${S}/arch/intel_usg/boards/arm_shared/scripts/redirect_url.sh ${D}/usr/ccsp/pam/redirect_url.sh
    install -m 755 ${S}/arch/intel_usg/boards/arm_shared/scripts/revert_redirect.sh ${D}/usr/ccsp/pam/revert_redirect.sh
    install -m 755 ${S}/arch/intel_usg/boards/arm_shared/scripts/redirect_url.sh ${D}/etc/redirect_url.sh
    install -m 755 ${S}/arch/intel_usg/boards/arm_shared/scripts/revert_redirect.sh ${D}/etc/revert_redirect.sh
    install -m 755 ${S}/arch/intel_usg/boards/arm_shared/scripts/restart_services.sh ${D}/etc/restart_services.sh
    install -m 755 ${S}/arch/intel_usg/boards/arm_shared/scripts/whitelist.sh ${D}/usr/ccsp/pam/whitelist.sh
    install -m 755 ${S}/arch/intel_usg/boards/arm_shared/scripts/moca_status.sh ${D}/usr/ccsp/pam/moca_status.sh
    install -m 777 ${D}/usr/bin/CcspPandMSsp -t ${D}/usr/ccsp/pam/

    install -d ${D}/fss/gw/usr/sbin
    ln -sf /sbin/ip.iproute2 ${D}/fss/gw/usr/sbin/ip

    #captiveportal redirection
    DISTRO_ENABLED="${@bb.utils.contains('DISTRO_FEATURES','webui_jst','true','false',d)}"
    if [ $DISTRO_ENABLED = 'false' ]; then
    sed -i "/captiveportaldhcp/a fi" ${D}/etc/revert_redirect.sh
    sed -i "/captiveportaldhcp/a lighttpd -f /var/lighttpd.conf" ${D}/etc/revert_redirect.sh
    sed -i "/captiveportaldhcp/a sleep 2" ${D}/etc/revert_redirect.sh
    sed -i "/captiveportaldhcp/a killall lighttpd" ${D}/etc/revert_redirect.sh
    sed -i "/captiveportaldhcp/a sed -i '\$d' /var/lighttpd.conf" ${D}/etc/revert_redirect.sh
    sed -i "/captiveportaldhcp/a sed -i '\$d' /var/lighttpd.conf" ${D}/etc/revert_redirect.sh
    sed -i "/captiveportaldhcp/a sed -e '/url.redirect/ s/^#*/#/' -i /var/lighttpd.conf" ${D}/etc/revert_redirect.sh
    sed -i "/captiveportaldhcp/a if [ \$CAPTIVEPORTAL == \"$\" ] ; then"  ${D}/etc/revert_redirect.sh
    sed -i "/captiveportaldhcp/a CAPTIVEPORTAL=\`cat /var/lighttpd.conf | grep captiveportal.php | cut -c1\`" ${D}/etc/revert_redirect.sh
    sed -i "/dibbler-server start/a fi" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a fi" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a lighttpd -f \$LIGHTTPD_CONF" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a sleep 2" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a killall lighttpd" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a sed -i '\$d' \$LIGHTTPD_CONF" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a sed -i '\$d' \$LIGHTTPD_CONF" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a sed -e '/url.redirect/ s/^#*/#/' -i \$LIGHTTPD_CONF" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a if [ \$CAPTIVEPORTAL == \"\$\" ] ; then" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a CAPTIVEPORTAL=\`cat /var/lighttpd.conf | grep captiveportal.php | cut -c1\`" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a if [ \"\$CaptivePortal_flag\" == 1 ] && [ \"\$1\" == \"false\" ] ; then" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a fi" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a lighttpd -f \$LIGHTTPD_CONF" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a sleep 2" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a killall lighttpd" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a fi" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a echo \"}\" >> \$LIGHTTPD_CONF" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a echo \"}\" >> \$LIGHTTPD_CONF" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a echo \"\\\\\$HTTP[\\\\\"host\\\\\"] !~ \\\\\":8080\\\\\" {  \\\\\$HTTP[\\\\\"url\\\\\"] !~ \\\\\"captiveportal.php\\\\\" {  \\\\\$HTTP[\\\\\"referer\\\\\"] == \\\\\"\\\\\" { url.redirect = ( \\\\\".*\\\\\" => \\\\\"http://10.0.0.1/captiveportal.php\\\\\" ) url.redirect-code = 303 }\" >> \$LIGHTTPD_CONF" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a else" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a fi" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a echo \"}\" >> \$LIGHTTPD_CONF" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a echo \"}\" >> \$LIGHTTPD_CONF" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a sed -i \"/captiveportal.php/ s/^#*//g\" \$LIGHTTPD_CONF" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a else" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a echo \"Already lighttpd was successfully running with captiveportal changes\"" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a if [ \"\$lighttpd\" == \"\$\" ] ; then" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a if [ \"\$lighttpd_flag\" == 1 ] ; then" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a lighttpd=\`cat /var/lighttpd.conf | grep captiveportal.php | cut -c1\`" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a lighttpd_flag=\`cat /var/lighttpd.conf | grep captiveportal.php | wc -l\`" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a if [ \"\$CaptivePortal_flag\" == 1 ] && [ \"\$1\" == \"true\" ] ; then" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a fi" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a CaptivePortal_flag=1" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a else" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a CaptivePortal_flag=0" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a if [ -f /nvram/reverted ] ; then" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a LIGHTTPD_CONF=/var/lighttpd.conf" ${D}/etc/restart_services.sh
    sed -i "/dibbler-server start/a #captiveportal redirection" ${D}/etc/restart_services.sh
    fi

########## ETHWAN Support
   sed -i "s/www.comcast.net/www.google.com/g" ${D}/etc/partners_defaults.json
   sed -i "s/\"Device.DeviceInfo.X_RDKCENTRAL-COM_Syndication.RDKB_UIBranding.AllowEthernetWAN\"\ :\ \"false\"\ \,/\"Device.DeviceInfo.X_RDKCENTRAL-COM_Syndication.RDKB_UIBranding.AllowEthernetWAN\" : \"true\" ,/g" ${D}/etc/partners_defaults.json

}


FILES_${PN}-ccsp += " \
    ${prefix}/ccsp/pam/CcspPandMSsp \
    /fss/gw/usr/sbin/ip \
"

RDEPENDS_${PN}-ccsp_append_dunfell = " bash"
