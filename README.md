# Citrix

Scripts and files for all things Citrix

## Project layout

This project is broken down into two sections.

- Product specific scripts (folder based)

- Citrix script packaging folders

## Script Packaging

Two folders have been added to this project to help with packaging up these usefull scripts and making them available for use within the [Citrix Developer Extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=CitrixDeveloper.citrixdeveloper-vscode)

- CitrixExtensionPackage - This is the base project that is used to create the VSIX script package for use within the Citrix Extension. For more information, visit the following [github repo])https://github.com/citrix/citrix-script-packager)

- CitrixVSIX - This folder is used to store both the RSS feed which VSCode consumes and the actual package VSIX file that contains all the scripts.

### Creating the package

If you would like to recreate the final package (for example if you would like to add a new script to the package) follow the instructions below.

1. Make sure you have the citrix-script-packager npm package installed. You can install it via the following command

    ``` sh
    npm install -g citrix-script-packager
    ```

1. Copy the new file into the CitrixExtensionPackage/packages/RyanCButler folder. You can either create a new folder if one doesn't exist or copy it into an existing product folder.

2. Change into the CitrixExtensionPackage directory and run the following command

    ```sh
    citrix-script-package -p
    ```
    This will repackage up everythin under the packages folder and creates a new vsix file. This file resides in the output directory.

### Updating the RSS feed

Once you have the package created, the Citrix Developer extension can consume an RSS feed of available script packages. You can use the github repo to host these packages and rss feed.

1. Make sure you have the npm tool citrix-script-feed installed to help build your RSS feed. For more information see the tools github repo [here](https://github.com/johnmcbride/citrix-script-feed-gen). You can install via the following command

    ```sh
    npm install -g citrix-script-feed
    ```

2. Once installed, copy your updated vsix files into the CitrixVSIX directory. (you can have more than one in the directory)

3. Change into the directory CitrixVSIX and run the following command
    ```sh
    citrix-script-feed create -d . -b ttps://github.com/ryancbutler/Citrix/CitrixVSIX -e RSS
    ```

    This will create a new feed.rss file with a list of all vsix in the current directory.

    **NOTE: If you are hosting the VSIX files in github you will need to add the following to the end of each VSIX link in the feed.rss file. Add '?raw=true' to the end of each VSIX line** 

### Enabling the RSS feed in the Citrix Developer Extension

Once you have the feed build, you will need to add the RSS Url into the Citrix Developer Extension. Below are the instructions to enable it.

1. Install the [Citrix Developer Extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=CitrixDeveloper.citrixdeveloper-vscode)

2. Open up settings by using the CMD/CTRL + Shift + P

3. Add the following to the settings file

    "citrixdeveloper.vsixrepositories": ["https://raw.githubusercontent.com/ryancbutler/citrix/CitrixVSIX/feed.rss"]

4. Once that has been added you can add the package by using CMD+Shift+P and selecting Install Citrix Package


## Troubleshooting the scripts.

If you receive an error within PowerShell with any of the scripts from Windows 7 or Windows 2008 R2 SP1 like the one mentioned below.  Please install [Windows Management Framework 4.0 KB2819745](https://www.microsoft.com/en-us/download/details.aspx?id=40855)
![Alt text](https://github.com/ryancbutler/Citrix/blob/images/images/ns-resterror.png?raw=true)


