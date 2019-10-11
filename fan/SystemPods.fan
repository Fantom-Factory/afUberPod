
internal const class SystemPods {
	private const Str[] sysPodNames			:= "docDomkit docIntro docLang docFanr docTools build compiler compilerDoc compilerJava compilerJs concurrent dom domkit email fandoc fanr fansh flux fluxText fwt gfx graphics inet obix sql syntax sys util web webfwt webmod wisp xml".lower.split
	private const Str[] skySparkPodNames	:= "arcbeam asn1 auth axon bacnet bacnetExt builderExt chart clusterMod codemirror connExt crypto debug def defc demoExt demogen devMod dict dictbase docFresco docgen docgfx docHaystack docSkySpark docTraining energyExt energyStarExt equipExt fileRepo folio folio3 folioStore fontMetrics fresco frescoRes ftp geoExt greenButtonExt haystack haystackExt hisExt hisKitExt hvacExt installMod ioExt javautil jobExt jssc kpiExt ldap legacy lightingExt mathExt mib migrate misc mlExt mobile modbusExt navMod noteExt obixExt opc opcExt pdf pdf2 ph phIct phIoT phScience pim pointExt projMod rdf replMod reportExt ruleExt scheduleExt sedona sedonaExt serialMod siteSparkExt skyarc skyarcd slf4j_nop smileCore snmpExt sparkExt sqlExt stackhub svg svggfx tariffExt templateHaystack tools ui uiBuilder uiDev uiFonts uiIcons uiMisc uiMod uiTest userMod vdom view view2 viz weatherExt xmlExt xqueryMod".lower.split

	Bool isSysPod(Str podName) {
		sysPodNames.contains(podName.lower)
	}

	Bool isSkyPod(Str podName) {
		skySparkPodNames.contains(podName.lower)
	}
}
