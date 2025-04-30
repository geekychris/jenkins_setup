#!groovy

import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

// Create admin user if it doesn't exist
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
if (hudsonRealm.getAllUsers().isEmpty()) {
    print "Creating admin user"
    hudsonRealm.createAccount("admin", "admin")
    instance.setSecurityRealm(hudsonRealm)
    
    def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
    strategy.setAllowAnonymousRead(false)
    instance.setAuthorizationStrategy(strategy)
    
    instance.save()
    print "Admin user created"
}
else {
    print "Admin user already exists"
}
