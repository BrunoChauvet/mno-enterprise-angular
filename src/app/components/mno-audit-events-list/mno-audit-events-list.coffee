#
# Mnoe Audit Events list
#

angular.module 'mnoEnterpriseAngular'
  .component('mnoAuditEventsList', {
    templateUrl: 'app/components/mno-audit-events-list/mno-audit-events-list.html',
    bindings: {
      view: '@'
    }
    controller: ($log, MnoeAuditEvents) ->
      vm = this

      vm.events =
        search: {}
        sort: "created_at.desc"
        nbItems: 20
        page: 1
        list: []

      # Widget state
      vm.state = vm.view

      # Manage sorting, search and pagination
      vm.callServer = (tableState) ->
        sort   = updateSort(tableState.sort)
        search = null
        fetchEvents(vm.events.nbItems, vm.events.offset, sort, search)

      # Update sorting parameters
      updateSort = (sortState = {}) ->
        sort = "created_at.desc"
        if sortState.predicate
          sort = sortState.predicate
          if sortState.reverse
            sort += ".desc"
          else
            sort += ".asc"

        # Update staff sort
        vm.events.sort = sort
        return sort

      # Fetch events
      fetchEvents = (limit, offset, sort = vm.events.sort, search = vm.events.search) ->
        vm.events.loading = true
        # TODO: search
        return MnoeAuditEvents.list(limit, offset, sort).then(
          (response) ->
            vm.events.totalItems = response.headers('x-total-count')
            vm.events.list = response.data
        ).finally(-> vm.events.loading = false)

      # Initial call and start the listeners
      fetchEvents(vm.events.nbItems, 0)

      return
  })
