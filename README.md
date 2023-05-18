# SonarScanner for SonarQube
SonarScanner Dockerfile to build if your server run on Linux and need to test NetCore applications.
I put together this solution because my Jenkins server didn't have a license, and Java 11 to run the SonarScanner plugin couldn't install it.

        Variables:
                    SONAR_HOST
                    SONAR_PRJ_KEY
                    SONAR_TOKEN

        SDK Version: 
                      3.1.407-buster
        Java Version:
                      16 (JDK)

In the same Pipeline you need to download your Net code, one of the steps in de Dockerfile copy your Net code to the container and then finally SonarScanner its execute, scan the code and then push the information to SonarQube Server.


