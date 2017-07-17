
# TODO: Remove DhbTeamSvc
DashboardOrganizationTeamsCtrl = ($scope, $window, $uibModal, $q, MnoeOrganizations, MnoeTeams, MnoeAppInstances, Utilities) ->
  'ngInject'

  #====================================
  # Pre-Initialization
  #====================================
  $scope.isLoading = true
  $scope.teams = []
  $scope.originalTeams = []
  $scope.appInstances = []

  #====================================
  # Scope Management
  #====================================
  # Initialize the data used by the directive
  $scope.initialize = (teams, appInstances) ->
    angular.copy(teams, $scope.teams)
    angular.copy(teams, $scope.originalTeams)
    realAppInstances = _.filter(appInstances, (i) -> i.status != 'terminated')
    angular.copy(realAppInstances, $scope.appInstances)
    $scope.isLoading = false

  $scope.isTeamEmpty = (team) ->
    team.users.length == 0

  $scope.hasTeams = ->
    $scope.teams.length > 0

  $scope.hasApps = ->
    $scope.appInstances.length > 0

  #====================================
  # Permissions matrix
  #====================================
  $scope.matrix = matrix = {}
  matrix.isLoading = false

  # Check if a team has access to the specified
  # app_instance
  # If appInstance is equal to the string 'all'
  # then it checks if the team has access to all
  # appInstances
  matrix.hasAccess = (team, appInstance) ->
    if angular.isString(appInstance) && appInstance == 'all'
      _.reduce($scope.appInstances,
        (memo, elem) ->
          memo && _.find(team.app_instances, (i)-> i.id == elem.id)?
        , true
      )
    else
      _.find(team.app_instances, (i)-> i.id == appInstance.id)?

  # Add access to the app if the team does not have
  # access and remove access if the team already
  # have access
  matrix.toggleAccess = (team, appInstance) ->
    self = matrix
    if (self.hasAccess(team, appInstance))
      self.removeAccess(team, appInstance)
    else
      self.addAccess(team, appInstance)

  # Add access to a specified appInstance
  # If appInstance is equal to the string 'all'
  # then it adds permissions to all appInstances
  matrix.addAccess = (team, appInstance) ->
    if angular.isString(appInstance) && appInstance == 'all'
      team.app_instances.length = 0
      angular.copy($scope.appInstances, team.app_instances)
    else
      unless _.find(team.app_instances, (e)-> e.id == appInstance.id)?
        team.app_instances.push(appInstance)

  # Remove access to a specified appInstance
  # If appInstance is equal to the string 'all'
  # then it removes permissions to all appInstances
  matrix.removeAccess = (team,appInstance) ->
    if angular.isString(appInstance) && appInstance == 'all'
      team.app_instances.length = 0
    else
      if (elem = _.find(team.app_instances, (e)-> e.id == appInstance.id))?
        idx = team.app_instances.indexOf(elem)
        team.app_instances.splice(idx,1)

  # Open the 'add team' modal
  matrix.addTeam = ->
    addTeamModal.open()

  # Open the 'remove team' modal
  matrix.removeTeam = (team)->
    teamDeletionModal.open(team)

  matrix.compileHash = (teams) ->
    _.reduce teams,
      (hash,t) ->
        hash += "#{t.id}:"
        hash += _.sortBy(_.pluck(t.app_instances,'id'),(n)->n).join()
        hash += "::"
      ,""

  matrix.isChanged = ->
    self = matrix
    self.compileHash($scope.teams) != self.compileHash($scope.originalTeams)

  matrix.cancel = ->
    _.each $scope.teams, (t) ->
      ot = _.find($scope.originalTeams,(e) -> e.id == t.id)
      angular.copy(ot.app_instances,t.app_instances)

  matrix.save = ->
    self = matrix
    self.isLoading = true

    qs = []
    _.each $scope.teams, (team) ->
      # Force empty array if no app_instances permissions
      realAppInstances = if team.app_instances.length >0 then team.app_instances else [{}]
      qs.push MnoeTeams.updateTeamAppInstances(team, realAppInstances)

    $q.all(qs).then(
      (->)
        self.errors = ''
        self.updateOriginalTeams()
      (errorsArray) ->
        self.errors = Utilities.processRailsError(errorsArray[0])
    ).finally(-> self.isLoading = false)

  matrix.updateOriginalTeams = ->
    _.each $scope.teams, (t) ->
      ot = _.find($scope.originalTeams,(e) -> e.id == t.id)
      angular.copy(t.app_instances,ot.app_instances)

  matrix.updateTeamName = (team) ->
    origTeam = _.find($scope.teams, (t) -> t.id == team.id)
    if team.name.length == 0
      team.name = origTeam.name
    else
      MnoeTeams.updateTeamName(team).then(
        (->)
          origTeam.name = team.name
        , ->
          team.name = origTeam.name
      )

  #====================================
  # Add Team modal
  #====================================
  $scope.addTeamModal = addTeamModal = {}
  addTeamModal.config = {
    instance: {
      backdrop: 'static'
      templateUrl: 'app/views/company/teams/modals/team-add-modal.html'
      size: 'lg'
      windowClass: 'inverse team-add-modal'
      scope: $scope
    }
  }

  # Open the modal
  addTeamModal.open = ->
    self = addTeamModal
    self.model = {}
    self.$instance = $uibModal.open(self.config.instance)
    self.isLoading = false

  # Close the modal
  addTeamModal.close = ->
    self = addTeamModal
    self.$instance.close()

  # Check if proceed btn should be
  # disabled
  addTeamModal.isProceedDisabled = ->
    self = addTeamModal
    !self.model.name? || self.model.name.length == 0

  # Create the team then close the
  # modal
  addTeamModal.proceed = ->
    self = addTeamModal
    self.isLoading = true
    MnoeTeams.addTeam(self.model).then(
      (team) ->
        self.errors = ''
        self.addToScope(team)
        self.close()
      (errors) ->
        self.errors = Utilities.processRailsError(errors)
    ).finally(-> self.isLoading = false)

  addTeamModal.addToScope = (team) ->
    $scope.teams.push(angular.copy(team))
    $scope.originalTeams.push(angular.copy(team))

  #====================================
  # Team Deletion Modal
  #====================================
  $scope.teamDeletionModal = teamDeletionModal = {}
  teamDeletionModal.config = {
    instance: {
      backdrop: 'static'
      templateUrl: 'app/views/company/teams/modals/team-delete-modal.html'
      size: 'lg'
      windowClass: 'inverse team-delete-modal'
      scope: $scope
    }
  }

  teamDeletionModal.open = (team) ->
    self = teamDeletionModal
    self.team = team
    self.$instance = $uibModal.open(self.config.instance)
    self.isLoading = false
    self.errors = ''

  teamDeletionModal.close = ->
    self = teamDeletionModal
    self.$instance.close()

  teamDeletionModal.proceed = ->
    self = teamDeletionModal
    self.isLoading = true
    MnoeTeams.deleteTeam(self.team.id).then(
      (data) ->
        self.errors = ''
        self.removeFromScope(self.team)
        self.close()
      (errors) ->
        self.errors = Utilities.processRailsError(errors)
    ).finally(-> self.isLoading = false)

  teamDeletionModal.removeFromScope = (team) ->
    team = _.find($scope.teams, (t) -> t.id == team.id)
    idx = $scope.teams.indexOf(team)
    $scope.teams.splice(idx,1) if idx >= 0

    team = _.find($scope.originalTeams, (t) -> t.id == team.id)
    idx = $scope.originalTeams.indexOf(team)
    $scope.originalTeams.splice(idx,1) if idx >= 0

  #====================================
  # Post-Initialization
  #====================================
  # Watch organization id and reload on change
  $scope.$watch(MnoeOrganizations.getSelectedId, (newValue) ->
    if newValue?
      # Get the new teams for this organization
      $q.all([MnoeTeams.getTeams(), MnoeAppInstances.getAppInstances()]).then(
        (responses) ->
          $scope.initialize(responses[0], responses[1])
      )
  )

angular.module 'mnoEnterpriseAngular'
  .directive('dashboardOrganizationTeams', ->
    return {
      restrict: 'A',
      scope: {
      },
      templateUrl: 'app/views/company/teams/organization-teams.html',
      controller: DashboardOrganizationTeamsCtrl
    }
  )
