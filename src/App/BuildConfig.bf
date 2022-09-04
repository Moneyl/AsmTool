using System.Collections;
using System;

namespace AsmTool.App
{
	public class BuildConfig
	{
		public String ProjectName = new .() ~delete _;
		public String AssetsBasePath = new .() ~delete _;
        public List<String> Arguments = new .() ~DeleteContainerAndItems!(_);

		public this()
		{

		}

		public this(StringView projectName, StringView assetsBasePath, String[] cliArgs)
		{
			ProjectName.Set(projectName);
			AssetsBasePath.Set(assetsBasePath);
            for (String arg in cliArgs)
            {
                String newArg = new .();
                newArg.Set(arg);
                Arguments.Add(newArg);
            }
		}
	}
}